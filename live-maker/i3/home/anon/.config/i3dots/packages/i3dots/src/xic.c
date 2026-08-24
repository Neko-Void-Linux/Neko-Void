#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

long parse_size(const char *str) {
    char *end;
    long val = strtol(str, &end, 10);
    if (*end == 'M' || *end == 'm') val *= 1024 * 1024;
    else if (*end == 'K' || *end == 'k') val *= 1024;
    return val;
}

int main(int argc, char *argv[]) {
    long max_single = 4 * 1024 * 1024;
    long chunk_size = 1024 * 1024;
    const char *filename = NULL;

    for (int i = 1; i < argc; i++) {
        if ((strcmp(argv[i], "-c") == 0 || strcmp(argv[i], "--chunk") == 0) && i + 1 < argc) {
            chunk_size = parse_size(argv[++i]);
        } else if ((strcmp(argv[i], "-s") == 0 || strcmp(argv[i], "--single") == 0) && i + 1 < argc) {
            max_single = parse_size(argv[++i]);
        } else {
            filename = argv[i];
        }
    }

    if (!filename) {
        fprintf(stderr, "Usage: %s [-c chunk_size] [-s single_max] <png_file>\n", argv[0]);
        return 1;
    }

    FILE *f = fopen(filename, "rb");
    if (!f) {
        perror("fopen");
        return 1;
    }

    if (fseek(f, 0, SEEK_END) != 0) {
        perror("fseek");
        fclose(f);
        return 1;
    }
    long size = ftell(f);
    if (size < 0) {
        perror("ftell");
        fclose(f);
        return 1;
    }
    if (fseek(f, 0, SEEK_SET) != 0) {
        perror("fseek");
        fclose(f);
        return 1;
    }

    unsigned char *data = malloc(size);
    if (!data) {
        perror("malloc");
        fclose(f);
        return 1;
    }

    if (fread(data, 1, size, f) != (size_t)size) {
        perror("fread");
        free(data);
        fclose(f);
        return 1;
    }
    fclose(f);

    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "XOpenDisplay failed\n");
        free(data);
        return 1;
    }

    Window win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0, 1, 1, 0, 0, 0);
    Atom clipboard = XInternAtom(dpy, "CLIPBOARD", False);
    Atom png_type = XInternAtom(dpy, "image/png", False);
    Atom targets = XInternAtom(dpy, "TARGETS", False);
    Atom incr_type = XInternAtom(dpy, "INCR", False);

    XSetSelectionOwner(dpy, clipboard, win, CurrentTime);
    if (XGetSelectionOwner(dpy, clipboard) != win) {
        fprintf(stderr, "XSetSelectionOwner failed\n");
        XCloseDisplay(dpy);
        free(data);
        return 1;
    }

    if (fork() > 0) {
        return 0;
    }

    XEvent ev;
    while (1) {
        XNextEvent(dpy, &ev);
        if (ev.type == SelectionClear) {
            break;
        }
        if (ev.type == SelectionRequest) {
            XSelectionRequestEvent *req = &ev.xselectionrequest;
            Atom prop = req->property;
            if (prop == None) {
                prop = req->target;
            }

            XSelectionEvent response = {
                .type = SelectionNotify,
                .display = req->display,
                .requestor = req->requestor,
                .selection = req->selection,
                .target = req->target,
                .property = prop,
                .time = req->time
            };

            if (req->target == targets) {
                Atom list[] = { targets, png_type };
                XChangeProperty(dpy, req->requestor, prop, XA_ATOM, 32,
                                PropModeReplace, (unsigned char *)list, 2);
            } else if (req->target == png_type) {
                if (size <= max_single) {
                    XChangeProperty(dpy, req->requestor, prop, png_type, 8,
                                    PropModeReplace, data, size);
                } else {
                    XSelectInput(dpy, req->requestor, PropertyChangeMask);
                    XChangeProperty(dpy, req->requestor, prop, incr_type, 32,
                                    PropModeReplace, (unsigned char *)&size, 1);
                    XSendEvent(dpy, req->requestor, True, 0, (XEvent *)&response);
                    XFlush(dpy);

                    long offset = 0;
                    XEvent pev;
                    while (offset < size) {
                        XNextEvent(dpy, &pev);
                        if (pev.type == PropertyNotify &&
                            pev.xproperty.window == req->requestor &&
                            pev.xproperty.atom == prop &&
                            pev.xproperty.state == PropertyDelete) {
                            long chunk = size - offset;
                            if (chunk > chunk_size) {
                                chunk = chunk_size;
                            }
                            XChangeProperty(dpy, req->requestor, prop, png_type, 8,
                                            PropModeReplace, data + offset, chunk);
                            offset += chunk;
                            XFlush(dpy);
                        }
                    }

                    while (1) {
                        XNextEvent(dpy, &pev);
                        if (pev.type == PropertyNotify &&
                            pev.xproperty.window == req->requestor &&
                            pev.xproperty.atom == prop &&
                            pev.xproperty.state == PropertyDelete) {
                            XChangeProperty(dpy, req->requestor, prop, png_type, 8,
                                            PropModeReplace, NULL, 0);
                            XFlush(dpy);
                            break;
                        }
                    }
                    continue;
                }
            } else {
                response.property = None;
            }
            XSendEvent(dpy, req->requestor, True, 0, (XEvent *)&response);
            XFlush(dpy);
        }
    }

    XCloseDisplay(dpy);
    free(data);
    return 0;
}
