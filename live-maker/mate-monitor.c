/*
 * mate-monitor.c – Monitor de cambios en directorios de aplicaciones
 *                  y reinicio automático de mate-panel.
 *
 * Compilación:
 *   gcc -o mate-monitor mate-monitor.c -D_GNU_SOURCE -Wall -Wextra -O2
 *
 * Uso:
 *   ./mate-monitor [-s]
 *
 * Lógica de reinicio (debounce adaptativo):
 *   - Un único cambio asentado  -> pkill + 'mate-panel --replace' inmediato.
 *   - Ráfaga (>1 cambio corto)  -> se agrupa; tras el último cambio, 5s de
 *                                  cooldown y entonces UN solo reinicio.
 *   Esto evita los reinicios en cadena que destruían el panel.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <stdbool.h>
#include <limits.h>

#define SCAN_INTERVAL_SEC  1     // cadencia de escaneo
#define SINGLE_SETTLE_SEC  1     // ventana para considerar "cambio único"
#define MULTI_COOLDOWN_SEC 5     // cooldown tras una ráfaga de cambios
#define KILL_GRACE_MS      400   // tiempo de cortesía para que el panel termine

#define DIR_PATH_LEN 512

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

// Estado vigilado de un directorio.
struct DirWatch {
    char   path[DIR_PATH_LEN];
    int    count;        // nº de archivos .desktop
    time_t mtime_sum;    // suma de st_mtime: detecta modificaciones de contenido
};

// --- Variables globales ---
static volatile sig_atomic_t keep_running = 1;   // bandera de salida
static bool silent_mode = false;                 // activado con -s

// --- Util: dormir milisegundos de forma portable (sin EINTR problemático) ---
static void sleep_ms(long ms) {
    struct timespec ts;
    ts.tv_sec  = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    while (nanosleep(&ts, &ts) == -1) {
        // sólo se interrumpe por señal; si no debemos salir, reintentamos
        if (!keep_running) break;
    }
}

// --- Manejador de señales (mínimo y async-signal-safe) ---
static void signal_handler(int sig) {
    (void) sig;
    keep_running = 0;
}

// --- Configuración de señales ---
static void setup_signals(void) {
    struct sigaction sa;
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;

    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    // Evitar zombies: el kernel recoge a los hijos que lancemos (pkill/panel).
    sa.sa_handler = SIG_IGN;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_NOCLDWAIT | SA_RESTART;
    sigaction(SIGCHLD, &sa, NULL);
}

// --- Escanea un directorio: cuenta .desktop y suma sus mtimes ---
// Devuelve false si no se pudo abrir (no existe aún -> no es error crítico).
static bool scan_dir(const char *path, int *count_out, time_t *mtime_sum_out) {
    DIR *dir = opendir(path);
    if (!dir)
        return false;

    int count = 0;
    time_t sum = 0;
    struct dirent *entry;
    char full[PATH_MAX];

    while ((entry = readdir(dir)) != NULL) {
        // Saltamos "." y ".." (y ocultos): su primer carácter es '.'.
        if (entry->d_name[0] == '.')
            continue;

        const char *ext = strrchr(entry->d_name, '.');
        if (!ext || strcmp(ext, ".desktop") != 0)
            continue;

        count++;
        int n = snprintf(full, sizeof(full), "%s/%s", path, entry->d_name);
        if (n < 0 || (size_t)n >= sizeof(full))
            continue;  // ruta demasiado larga: la ignoramos con seguridad

        struct stat st;
        if (stat(full, &st) == 0)
            sum += st.st_mtime;
    }

    closedir(dir);
    *count_out = count;
    *mtime_sum_out = sum;
    return true;
}

// --- Lanza un proceso desatendido (doble fork + setsid) ---
// argv es un array terminado en NULL. Nunca bloquea al llamador.
static void spawn_detached(char *const argv[]) {
    pid_t pid = fork();
    if (pid != 0)
        return;  // padre (o fork fallido): seguimos sin esperar

    // Hijo: nueva sesión, independiente del terminal y del padre.
    setsid();

    // Segundo fork para asegurar que no adquiera nunca un terminal.
    pid_t pid2 = fork();
    if (pid2 != 0)
        _exit(EXIT_SUCCESS);

    // Silenciar E/S heredadas para no ensuciar el log del monitor.
    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);

    execvp(argv[0], argv);
    _exit(127);  // sólo si execvp falla
}

// --- Secuencia de reinicio real: matar y volver a lanzar ---
static void restart_panel(void) {
    char *kill_argv[]   = { "pkill", "-x", "mate-panel", NULL };
    spawn_detached(kill_argv);

    // Dar tiempo a que el proceso termine antes de relanzar.
    sleep_ms(KILL_GRACE_MS);

    char *panel_argv[]  = { "mate-panel", "--replace", NULL };
    spawn_detached(panel_argv);
}

// --- Imprime sólo si no estamos en modo silencioso ---
static void log_msg(const char *fmt, ...) {
    if (silent_mode)
        return;
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
}

// --- Función principal ---
int main(int argc, char *argv[]) {
    // --- Procesar argumentos ---
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-s") == 0) {
            silent_mode = true;
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            fprintf(stderr, "Uso: %s [-s]\n", argv[0]);
            fprintf(stderr, "Monitoriza cambios en .desktop y reinicia mate-panel.\n");
            fprintf(stderr, "  -s   modo silencioso\n");
            return EXIT_SUCCESS;
        } else {
            fprintf(stderr, "Error: opción desconocida '%s'. Usa -h.\n", argv[i]);
            return EXIT_FAILURE;
        }
    }

    // --- Construir rutas ---
    const char *home = getenv("HOME");
    if (!home) {
        fprintf(stderr, "Error: la variable HOME no está definida\n");
        return EXIT_FAILURE;
    }

    struct DirWatch dirs[2];
    if (snprintf(dirs[0].path, sizeof(dirs[0].path),
                 "%s/.local/share/applications", home) >= (int)sizeof(dirs[0].path)) {
        fprintf(stderr, "Error: ruta HOME demasiado larga\n");
        return EXIT_FAILURE;
    }
    snprintf(dirs[1].path, sizeof(dirs[1].path), "%s", "/usr/share/applications");

    // --- Inicializar contadores ---
    for (int i = 0; i < 2; i++) {
        if (!scan_dir(dirs[i].path, &dirs[i].count, &dirs[i].mtime_sum)) {
            dirs[i].count = 0;
            dirs[i].mtime_sum = 0;
            log_msg("Aviso: no se pudo abrir %s (¿aún no existe?)", dirs[i].path);
        }
    }

    if (!silent_mode) {
        printf("Monitorizando:\n  %s (%d)\n  %s (%d)\n",
               dirs[0].path, dirs[0].count, dirs[1].path, dirs[1].count);
        printf("Debounce: cambio único -> inmediato | ráfaga -> %ds cooldown\n",
               MULTI_COOLDOWN_SEC);
        fflush(stdout);
    }

    setup_signals();

    // --- Bucle principal con debounce adaptativo ---
    int    pending     = 0;        // cambios acumulados sin reiniciar
    time_t last_change = 0;        // timestamp del último cambio detectado

    while (keep_running) {
        sleep(SCAN_INTERVAL_SEC);
        if (!keep_running) break;

        bool changed = false;
        for (int i = 0; i < 2; i++) {
            int    c;
            time_t m;
            if (!scan_dir(dirs[i].path, &c, &m))
                continue;  // directorio inaccesible este ciclo

            if (c != dirs[i].count || m != dirs[i].mtime_sum) {
                log_msg("Cambio en %s: %d -> %d",
                        dirs[i].path, dirs[i].count, c);
                dirs[i].count      = c;
                dirs[i].mtime_sum  = m;
                changed = true;
            }
        }

        time_t now = time(NULL);

        if (changed) {
            // Hay movimiento: acumular y seguir esperando a que se asiente.
            pending++;
            last_change = now;
            log_msg("Cambio acumulado (total: %d)", pending);
            continue;
        }

        // Sin cambios nuevos este ciclo: evaluar si toca reiniciar.
        if (pending > 0) {
            long settled = (long)difftime(now, last_change);

            if (pending == 1) {
                // Cambio único: tras asentarse la ventana corta, reiniciar ya.
                if (settled >= SINGLE_SETTLE_SEC) {
                    log_msg("Cambio único asentado: reiniciando mate-panel...");
                    restart_panel();
                    pending = 0;
                }
            } else {
                // Ráfaga: cooldown de 5s desde el último cambio.
                long remaining = MULTI_COOLDOWN_SEC - settled;
                if (remaining > 0) {
                    log_msg("Ráfaga de %d cambios; cooldown %lds...",
                            pending, remaining);
                } else {
                    log_msg("Cooldown cumplido (%d cambios agrupados): reiniciando...",
                            pending);
                    restart_panel();
                    pending = 0;
                }
            }
        }
    }

    log_msg("Monitor detenido correctamente.");
    return EXIT_SUCCESS;
}
