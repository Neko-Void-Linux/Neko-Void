/*
 * mate-monitor.c – Monitor de cambios en directorios de aplicaciones
 *                  y reinicio automático de mate-panel con watchdog.
 *
 * Compilación:
 *   gcc -o mate-monitor mate-monitor.c -D_GNU_SOURCE -Wall -Wextra -O2
 *
 * Uso:
 *   ./mate-monitor [-s]
 *
 * Lógica de reinicio (debounce adaptativo + watchdog):
 *   - Validación de entorno: sólo se ejecuta dentro de una sesión MATE.
 *   - Instancia única garantizada por usuario vía flock() en /tmp.
 *   - Un único cambio asentado  -> pkill + 'mate-panel --replace' inmediato.
 *   - Ráfaga (>1 cambio corto)  -> se agrupa; tras el último cambio, 5s de
 *                                  cooldown y entonces UN solo reinicio.
 *   - Watchdog: si mate-panel no aparece en el sistema por >3 segundos,
 *                 se relanza automáticamente con 'nohup mate-panel'.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <stdbool.h>
#include <limits.h>

#define SCAN_INTERVAL_SEC        1     // cadencia de escaneo
#define SINGLE_SETTLE_SEC        1     // ventana para considerar "cambio único"
#define MULTI_COOLDOWN_SEC       5     // cooldown tras una ráfaga de cambios
#define KILL_GRACE_MS            400   // tiempo de cortesía para que el panel termine
#define PANEL_DEAD_THRESHOLD_SEC 3     // segundos que el panel puede estar muerto antes de relanzarlo

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

// --- Verifica si la sesión gráfica actual corresponde a MATE ---
static bool is_mate_session(void) {
    const char *xdg_desktop = getenv("XDG_CURRENT_DESKTOP");
    if (xdg_desktop && strcasestr(xdg_desktop, "MATE") != NULL) {
        return true;
    }

    const char *session = getenv("DESKTOP_SESSION");
    if (session && strcasestr(session, "MATE") != NULL) {
        return true;
    }

    return false;
}

// --- Asegura que sólo corra una instancia por usuario ---
// Devuelve el descriptor abierto (>=0) si obtuvo el candado,
// -2 si ya hay otra instancia activa, o -1 en caso de error.
static int acquire_single_instance_lock(void) {
    char lock_path[128];
    snprintf(lock_path, sizeof(lock_path), "/tmp/mate-monitor-%d.lock", getuid());

    // O_CLOEXEC evita que los hijos lanzados por spawn_detached hereden el candado
    int fd = open(lock_path, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
    if (fd == -1) {
        perror("open lock");
        return -1;
    }

    if (flock(fd, LOCK_EX | LOCK_NB) == -1) {
        if (errno == EWOULDBLOCK) {
            close(fd);
            return -2;
        }
        perror("flock");
        close(fd);
        return -1;
    }

    if (ftruncate(fd, 0) == 0) {
        dprintf(fd, "%d\n", getpid());
    }

    return fd;
}

// --- Util: dormir milisegundos de forma portable (sin EINTR problemático) ---
static void sleep_ms(long ms) {
    struct timespec ts;
    ts.tv_sec  = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    while (nanosleep(&ts, &ts) == -1) {
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
static bool scan_dir(const char *path, int *count_out, time_t *mtime_sum_out) {
    DIR *dir = opendir(path);
    if (!dir)
        return false;

    int count = 0;
    time_t sum = 0;
    struct dirent *entry;
    char full[PATH_MAX];

    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.')
            continue;

        const char *ext = strrchr(entry->d_name, '.');
        if (!ext || strcmp(ext, ".desktop") != 0)
            continue;

        count++;
        int n = snprintf(full, sizeof(full), "%s/%s", path, entry->d_name);
        if (n < 0 || (size_t)n >= sizeof(full))
            continue;

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
static void spawn_detached(char *const argv[]) {
    pid_t pid = fork();
    if (pid != 0)
        return;

    setsid();

    pid_t pid2 = fork();
    if (pid2 != 0)
        _exit(EXIT_SUCCESS);

    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);

    execvp(argv[0], argv);
    _exit(127);
}

// --- Secuencia de reinicio real: matar y volver a lanzar ---
static void restart_panel(void) {
    char *kill_argv[]  = { "pkill", "-x", "mate-panel", NULL };
    spawn_detached(kill_argv);

    sleep_ms(KILL_GRACE_MS);

    char *panel_argv[] = { "mate-panel", "--replace", NULL };
    spawn_detached(panel_argv);
}

// --- Verifica si mate-panel está corriendo leyendo /proc directamente ---
static bool is_panel_running(void) {
    DIR *proc = opendir("/proc");
    if (!proc)
        return false;

    struct dirent *ent;
    char path[280];
    char comm[64];
    bool found = false;

    while ((ent = readdir(proc)) != NULL) {
        if (ent->d_name[0] < '0' || ent->d_name[0] > '9')
            continue;

        snprintf(path, sizeof(path), "/proc/%s/comm", ent->d_name);
        FILE *f = fopen(path, "r");
        if (f) {
            if (fgets(comm, sizeof(comm), f)) {
                comm[strcspn(comm, "\n")] = '\0';
                if (strcmp(comm, "mate-panel") == 0) {
                    found = true;
                }
            }
            fclose(f);
        }
        if (found)
            break;
    }

    closedir(proc);
    return found;
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

    // --- Verificar que estamos en MATE antes de hacer nada ---
    if (!is_mate_session()) {
        log_msg("Entorno no es MATE (XDG_CURRENT_DESKTOP='%s'). Saliendo.",
                getenv("XDG_CURRENT_DESKTOP") ? getenv("XDG_CURRENT_DESKTOP") : "no definido");
        return EXIT_SUCCESS;
    }

    // --- Garantizar ejecución única ---
    int lock_fd = acquire_single_instance_lock();
    if (lock_fd == -2) {
        log_msg("mate-monitor ya está en ejecución. Saliendo.");
        return EXIT_SUCCESS;
    } else if (lock_fd < 0) {
        return EXIT_FAILURE;
    }

    // --- Construir rutas ---
    const char *home = getenv("HOME");
    if (!home) {
        fprintf(stderr, "Error: la variable HOME no está definida\n");
        close(lock_fd);
        return EXIT_FAILURE;
    }

    struct DirWatch dirs[2];
    if (snprintf(dirs[0].path, sizeof(dirs[0].path),
        "%s/.local/share/applications", home) >= (int)sizeof(dirs[0].path)) {
        fprintf(stderr, "Error: ruta HOME demasiado larga\n");
        close(lock_fd);
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
        printf("Watchdog: relanzamiento con nohup si el panel está muerto >%ds\n",
               PANEL_DEAD_THRESHOLD_SEC);
        fflush(stdout);
    }

    setup_signals();

    // --- Bucle principal con debounce adaptativo y watchdog ---
    int    pending           = 0;
    time_t last_change       = 0;
    time_t panel_dead_since  = 0;
    time_t last_restart_time = 0;

    while (keep_running) {
        sleep(SCAN_INTERVAL_SEC);
        if (!keep_running) break;

        time_t now = time(NULL);

        // --- Watchdog: verificar si el panel está muerto ---
        bool running = is_panel_running();
        if (!running) {
            if (panel_dead_since == 0) {
                panel_dead_since = now;
            } else if (now - panel_dead_since >= PANEL_DEAD_THRESHOLD_SEC) {
                if (now - last_restart_time > 5) {
                    log_msg("Watchdog: mate-panel ausente por %ld s. Relanzando con nohup...",
                            (long)(now - panel_dead_since));
                    char *nohup_argv[] = { "sh", "-c", "nohup mate-panel >/dev/null 2>&1 &", NULL };
                    spawn_detached(nohup_argv);
                    last_restart_time = now;
                    panel_dead_since = 0;
                }
            }
        } else {
            panel_dead_since = 0;
        }

        // --- Monitoreo de directorios ---
        bool changed = false;
        for (int i = 0; i < 2; i++) {
            int    c;
            time_t m;
            if (!scan_dir(dirs[i].path, &c, &m))
                continue;

            if (c != dirs[i].count || m != dirs[i].mtime_sum) {
                log_msg("Cambio en %s: %d -> %d",
                        dirs[i].path, dirs[i].count, c);
                dirs[i].count     = c;
                dirs[i].mtime_sum = m;
                changed = true;
            }
        }

        if (changed) {
            pending++;
            last_change = now;
            log_msg("Cambio acumulado (total: %d)", pending);
            continue;
        }

        // --- Evaluar reinicio si hay cambios pendientes ---
        if (pending > 0) {
            long settled = (long)difftime(now, last_change);

            if (pending == 1) {
                if (settled >= SINGLE_SETTLE_SEC) {
                    log_msg("Cambio único asentado: reiniciando mate-panel...");
                    restart_panel();
                    last_restart_time = now;
                    pending = 0;
                }
            } else {
                long remaining = MULTI_COOLDOWN_SEC - settled;
                if (remaining > 0) {
                    log_msg("Ráfaga de %d cambios; cooldown %lds...",
                            pending, remaining);
                } else {
                    log_msg("Cooldown cumplido (%d cambios agrupados): reiniciando...",
                            pending);
                    restart_panel();
                    last_restart_time = now;
                    pending = 0;
                }
            }
        }
    }

    log_msg("Monitor detenido correctamente.");
    close(lock_fd);
    return EXIT_SUCCESS;
}
