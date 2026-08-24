#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <signal.h>
#include <poll.h>
#include <malloc.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <pwd.h>

int debug_mode = 0;
#define debug_log(...) if (debug_mode) { printf("[%lld] ", get_millis()); printf(__VA_ARGS__); fflush(stdout); }

Atom active_window_atom;
Atom wm_state_atom;
Atom fullscreen_atom;
Atom pid_atom;

char launch_cmd[512] = "";
int  delay_ms        = 300; // ventana de gracia por defecto

// Método de autohide: KILL (mata proceso) o HIDE (oculta ventana)
typedef enum { METHOD_KILL, METHOD_HIDE } Method;
Method method = METHOD_KILL;

// ── Máquina de estados ────────────────────────────────────────────────────────
// IDLE      : barra oculta, gatillo activo
// LAUNCHING : comando enviado, buscando ventana de polybar (no bloqueante)
// VISIBLE   : barra visible, monitoreando salida y fullscreen
// GRACE     : cursor salió, deadline pendiente; cancelable si el cursor regresa
typedef enum { STATE_IDLE, STATE_LAUNCHING, STATE_VISIBLE, STATE_GRACE } State;

long long get_millis(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

int x_error_handler(Display *d, XErrorEvent *e) { (void)d; (void)e; return 0; }

// Fork+exec sin waitpid: SIGCHLD=SIG_IGN auto-reapea hijos
void run_cmd_async(const char *cmd, char *const argv[]) {
    pid_t pid = fork();
    if (pid == 0) {
        int null = open("/dev/null", O_WRONLY);
        if (null != -1) {
            dup2(null, STDOUT_FILENO);
            dup2(null, STDERR_FILENO);
            close(null);
        }
        execvp(cmd, argv);
        _exit(1);
    }
}

Window find_polybar_window(Display *display, Window local_root) {
    Window root, parent, *children = NULL;
    unsigned int n = 0;
    Window found = 0;

    if (!XQueryTree(display, local_root, &root, &parent, &children, &n))
        return 0;

    for (unsigned int i = 0; i < n && !found; i++) {
        XClassHint h;
        if (XGetClassHint(display, children[i], &h)) {
            if (h.res_name && strcasecmp(h.res_name, "polybar") == 0)
                found = children[i];
            if (h.res_name)  XFree(h.res_name);
            if (h.res_class) XFree(h.res_class);
        }
        if (!found)
            found = find_polybar_window(display, children[i]);
    }

    if (children) XFree(children);
    return found;
}

pid_t get_window_pid(Display *display, Window win) {
    if (pid_atom == None) return 0;

    Atom type; int fmt;
    unsigned long n, after;
    unsigned char *prop = NULL;
    pid_t pid = 0;

    if (XGetWindowProperty(display, win, pid_atom, 0, 1, False,
                           XA_CARDINAL, &type, &fmt, &n, &after, &prop) == Success) {
        if (prop) { pid = *(pid_t *)prop; XFree(prop); }
    }
    return pid;
}

int is_window_fullscreen(Display *display, Window root) {
    if (!active_window_atom || !wm_state_atom || !fullscreen_atom) return 0;

    Atom type; int fmt;
    unsigned long n, after;
    unsigned char *prop = NULL;
    Window active = 0;
    int full = 0;

    if (XGetWindowProperty(display, root, active_window_atom, 0, 1, False,
                           XA_WINDOW, &type, &fmt, &n, &after, &prop) == Success) {
        if (prop) { active = *(Window *)prop; XFree(prop); }
    }
    if (!active) return 0;

    if (XGetWindowProperty(display, active, wm_state_atom, 0, 1024, False,
                           XA_ATOM, &type, &fmt, &n, &after, &prop) == Success) {
        if (prop) {
            Atom *states = (Atom *)prop;
            for (unsigned long i = 0; i < n; i++) {
                if (states[i] == fullscreen_atom) { full = 1; break; }
            }
            XFree(prop);
        }
    }
    return full;
}

// Transición a IDLE: oculta o mata polybar y reactiva gatillo
static void kill_polybar_and_idle(Display *display, Window polybar_win,
                                   Window trigger_win, State *state,
                                   long long *grace_deadline, Window *pwin,
                                   long long *last_hide_time) {
    // Ocultar ventana de forma instantánea vía X11
    XUnmapWindow(display, polybar_win);
    XFlush(display);

    if (method == METHOD_KILL) {
        pid_t pid = get_window_pid(display, polybar_win);
        if (pid > 0) kill(pid, SIGTERM);
        *pwin = 0; // resetear ventana en modo kill
    }

    *last_hide_time = get_millis();
    *grace_deadline = -1;
    *state          = STATE_IDLE;

    XMapWindow(display, trigger_win);
    XFlush(display);
    malloc_trim(0);
}

int main(int argc, char *argv[]) {
    char *position_arg = NULL;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--debug") || !strcmp(argv[i], "-d")) {
            debug_mode = 1;
        } else if ((!strcmp(argv[i], "--delay") || !strcmp(argv[i], "-t")) && i + 1 < argc) {
            int ms = atoi(argv[++i]);
            if (ms >= 0) delay_ms = ms;
        } else if ((!strcmp(argv[i], "--position") || !strcmp(argv[i], "-p")) && i + 1 < argc) {
            position_arg = argv[++i];
        } else if ((!strcmp(argv[i], "--method") || !strcmp(argv[i], "-m")) && i + 1 < argc) {
            char *m = argv[++i];
            if (!strcmp(m, "hide") || !strcmp(m, "toggle")) {
                method = METHOD_HIDE;
            } else {
                method = METHOD_KILL;
            }
        }
    }

    // Auto-reap hijos sin waitpid
    signal(SIGCHLD, SIG_IGN);
    XSetErrorHandler(x_error_handler);

    Display *display = XOpenDisplay(NULL);
    if (!display) { fprintf(stderr, "Error: No X11 display\n"); return 1; }

    Window root          = DefaultRootWindow(display);
    int    screen_width  = DisplayWidth(display, DefaultScreen(display));
    int    screen_height = DisplayHeight(display, DefaultScreen(display));

    active_window_atom = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
    wm_state_atom      = XInternAtom(display, "_NET_WM_STATE", False);
    fullscreen_atom    = XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", False);
    pid_atom           = XInternAtom(display, "_NET_WM_PID", False);

    unsigned int pheight = 30;

    int is_top = 0; // Default a bottom (0)
    char *bar_pos = position_arg ? position_arg : getenv("BAR_POSITION");
    if (bar_pos && !strcasecmp(bar_pos, "top")) is_top = 1;
    else if (bar_pos && !strcasecmp(bar_pos, "bottom")) is_top = 0;

    // Construir comando de lanzamiento
    char *config_dir = getenv("POLYBAR_CONFIG_DIR");
    if (config_dir) {
        snprintf(launch_cmd, sizeof(launch_cmd),
                 "%s/run_static.sh >/dev/null 2>&1 &", config_dir);
    } else {
        char *home = getenv("HOME");
        if (!home) {
            struct passwd *pw = getpwuid(getuid());
            if (pw) home = pw->pw_dir;
        }
        snprintf(launch_cmd, sizeof(launch_cmd),
                 "%s/.config/polybar/run_static.sh >/dev/null 2>&1 &", home ? home : "");
    }

    State     state          = STATE_IDLE;
    Window    polybar_win    = 0;
    long long grace_deadline = -1;
    long long launch_start   = 0;
    long long last_hide_time = 0;

    // Limpieza inicial o vinculación inteligente si polybar ya está activa
    {
        Window existing = find_polybar_window(display, root);
        if (existing) {
            if (method == METHOD_HIDE) {
                debug_log("[Autohide] Polybar activa detectada. Vinculando y ocultando...\n");
                XUnmapWindow(display, existing);
                XFlush(display);
                polybar_win = existing;

                // Geometría y coordenadas absolutas
                Window rr; int px, py;
                unsigned int pw, pb, pd;
                XGetGeometry(display, polybar_win, &rr, &px, &py, &pw, &pheight, &pb, &pd);

                int absolute_x = 0, absolute_y = 0;
                Window child_ret;
                XTranslateCoordinates(display, polybar_win, root, 0, 0, &absolute_x, &absolute_y, &child_ret);
                is_top = (absolute_y < screen_height / 2) ? 1 : 0;

                XSelectInput(display, polybar_win, EnterWindowMask | LeaveWindowMask | StructureNotifyMask);
                XFlush(display);
                
                state = STATE_IDLE;
            } else {
                debug_log("[Autohide] Limpiando polybar activa...\n");
                XUnmapWindow(display, existing);
                XFlush(display);
                pid_t pid = get_window_pid(display, existing);
                if (pid > 0) kill(pid, SIGTERM);
                usleep(50000);
            }
        }
    }

    int trigger_y = is_top ? 0 : (screen_height - 1);

    XSetWindowAttributes wattrs;
    wattrs.event_mask        = EnterWindowMask;
    wattrs.override_redirect = True;

    Window trigger_win = XCreateWindow(
        display, root, 0, trigger_y, screen_width, 1,
        0, CopyFromParent, InputOnly, CopyFromParent,
        CWEventMask | CWOverrideRedirect, &wattrs
    );
    XMapWindow(display, trigger_win);
    XFlush(display);

    debug_log("[Autohide] Gatillo listo y=%d  delay=%dms  método=%s\n",
              trigger_y, delay_ms, (method == METHOD_HIDE) ? "hide" : "kill");

    struct pollfd pfd = { .fd = ConnectionNumber(display), .events = POLLIN };

    malloc_trim(0);

    while (1) {
        long long now = get_millis();

        // ── Calcular timeout de poll ──────────────────────────────────────
        int poll_timeout;
        switch (state) {
            case STATE_IDLE:
                poll_timeout = -1;
                break;
            case STATE_LAUNCHING:
                poll_timeout = 50;   // reintentar búsqueda cada 50ms
                break;
            case STATE_VISIBLE:
                poll_timeout = 200;  // detectar fullscreen
                break;
            case STATE_GRACE: {
                long long rem = grace_deadline - now;
                poll_timeout  = (rem > 0) ? (int)rem : 0;
                break;
            }
            default:
                poll_timeout = -1;
        }

        if (!XPending(display))
            poll(&pfd, 1, poll_timeout);

        now = get_millis();

        // ── Acciones de timeout ───────────────────────────────────────────

        // LAUNCHING: búsqueda no-bloqueante de la ventana de polybar
        if (state == STATE_LAUNCHING) {
            Window w = find_polybar_window(display, root);
            if (w) {
                XWindowAttributes xa;
                if (XGetWindowAttributes(display, w, &xa) && xa.map_state == IsViewable) {
                    polybar_win = w;

                    Window rr; int px, py;
                    unsigned int pw, pb, pd;
                    XGetGeometry(display, polybar_win, &rr, &px, &py, &pw, &pheight, &pb, &pd);

                    // Traducir coordenadas relativas del contenedor i3 a absolutas de pantalla
                    int absolute_x = 0, absolute_y = 0;
                    Window child_ret;
                    XTranslateCoordinates(display, polybar_win, root, 0, 0, &absolute_x, &absolute_y, &child_ret);

                    // Auto-detectar posición real de la barra
                    is_top = (absolute_y < screen_height / 2) ? 1 : 0;
                    debug_log("[Autohide] Posición detectada: %s (y_abs=%d)\n", is_top ? "top" : "bottom", absolute_y);

                    trigger_y = is_top ? 0 : (screen_height - 1);
                    XMoveResizeWindow(display, trigger_win, 0, trigger_y, screen_width, 1);

                    // EnterWindow: para cancelar gracia si cursor regresa
                    // LeaveWindow: para iniciar gracia al salir
                    // StructureNotify: para detectar destrucción inesperada
                    XSelectInput(display, polybar_win,
                                 EnterWindowMask | LeaveWindowMask | StructureNotifyMask);
                    XFlush(display);

                    state = STATE_VISIBLE;
                    XRaiseWindow(display, polybar_win);
                    XFlush(display);
                    debug_log("[Autohide] Polybar vinculada (ID:%lu h:%u)\n", polybar_win, pheight);

                    // Si el cursor ya salió durante el tiempo de carga, iniciar gracia de inmediato
                    Window rw, cw;
                    int rx, ry, wx, wy;
                    unsigned int mask;
                    XQueryPointer(display, root, &rw, &cw, &rx, &ry, &wx, &wy, &mask);

                    int in_bar = is_top
                        ? (ry >= 0 && ry < (int)pheight)
                        : (ry >= screen_height - (int)pheight && ry < screen_height);

                    if (!in_bar) {
                        debug_log("[Autohide] Cursor ya fuera al vincular. Gracia %dms.\n", delay_ms);
                        grace_deadline = get_millis() + delay_ms;
                        state          = STATE_GRACE;
                    }
                }
            } else if (now - launch_start > 2000) {
                // polybar no apareció en 2s → volver a IDLE
                debug_log("[Autohide] Timeout de launch. Reset.\n");
                state = STATE_IDLE;
                XMapWindow(display, trigger_win);
                XFlush(display);
            }
        }

        // GRACE: gracia expirada → unmap/kill
        if (state == STATE_GRACE && now >= grace_deadline) {
            debug_log("[Autohide] Gracia expirada. Ocultando/Matando...\n");
            kill_polybar_and_idle(display, polybar_win, trigger_win,
                                  &state, &grace_deadline, &polybar_win, &last_hide_time);
        }

        // VISIBLE: detectar pantalla completa → unmap/kill inmediato sin gracia
        if (state == STATE_VISIBLE && is_window_fullscreen(display, root)) {
            debug_log("[Autohide] Fullscreen. Ocultando/Matando inmediato.\n");
            kill_polybar_and_idle(display, polybar_win, trigger_win,
                                  &state, &grace_deadline, &polybar_win, &last_hide_time);
        }

        // ── Eventos X ────────────────────────────────────────────────────
        while (XPending(display)) {
            XEvent ev;
            XNextEvent(display, &ev);
            now = get_millis();

            // Cursor entró en el gatillo → lanzar u mostrar polybar
            if (ev.type == EnterNotify && ev.xcrossing.window == trigger_win) {
                if (state == STATE_IDLE &&
                    now - last_hide_time >= 0 &&
                    !is_window_fullscreen(display, root)) {

                    if (method == METHOD_HIDE && polybar_win != 0) {
                        debug_log("[Autohide] Gatillo. Mostrando Polybar...\n");
                        XMapWindow(display, polybar_win);
                        XRaiseWindow(display, polybar_win);
                        XUnmapWindow(display, trigger_win);
                        XFlush(display);

                        // Si el cursor ya salió durante la transición rápida, iniciar gracia
                        Window rw, cw;
                        int rx, ry, wx, wy;
                        unsigned int mask;
                        XQueryPointer(display, root, &rw, &cw, &rx, &ry, &wx, &wy, &mask);

                        int in_bar = is_top
                            ? (ry >= 0 && ry < (int)pheight)
                            : (ry >= screen_height - (int)pheight && ry < screen_height);

                        if (!in_bar) {
                            debug_log("[Autohide] Cursor ya fuera al mapear. Gracia %dms.\n", delay_ms);
                            grace_deadline = now + delay_ms;
                            state          = STATE_GRACE;
                        } else {
                            state = STATE_VISIBLE;
                        }
                    } else {
                        debug_log("[Autohide] Gatillo. Lanzando Polybar...\n");
                        system(launch_cmd);           // la cmd lleva & → shell retorna rápido
                        XUnmapWindow(display, trigger_win);
                        XFlush(display);
                        launch_start = now;
                        state        = STATE_LAUNCHING;
                    }
                }
                continue;
            }

            // Cursor regresó a la barra durante la gracia → cancelar
            if (state == STATE_GRACE &&
                ev.type == EnterNotify && ev.xcrossing.window == polybar_win) {
                debug_log("[Autohide] Cursor regresó. Gracia cancelada.\n");
                grace_deadline = -1;
                state          = STATE_VISIBLE;
                continue;
            }

            // Cursor salió de la barra → iniciar ventana de gracia
            if ((state == STATE_VISIBLE || state == STATE_GRACE) &&
                ev.type == LeaveNotify &&
                ev.xcrossing.window == polybar_win &&
                ev.xcrossing.detail != NotifyInferior) {

                debug_log("[Autohide] Cursor salió. Gracia %dms.\n", delay_ms);
                grace_deadline = now + delay_ms;
                state          = STATE_GRACE;
                continue;
            }

            // Polybar destruida externamente (crash, pkill, etc.)
            if (polybar_win &&
                ev.type == DestroyNotify &&
                ev.xdestroywindow.window == polybar_win) {
                debug_log("[Autohide] Polybar destruida externamente. Reset.\n");
                polybar_win    = 0;
                grace_deadline = -1;
                last_hide_time = now;
                state          = STATE_IDLE;
                XMapWindow(display, trigger_win);
                XFlush(display);
                malloc_trim(0);
                continue;
            }
        }
    }

    XCloseDisplay(display);
    return 0;
}
