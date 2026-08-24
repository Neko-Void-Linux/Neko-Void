#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stdint.h>
#include <stdbool.h>
#include <signal.h>

#define I3_IPC_MAGIC "i3-ipc"
#define I3_IPC_MAGIC_LEN 6
#define I3_IPC_SUBSCRIBE 2

#define MPV_SOCKET "/tmp/mpv-live-wp.sock"

// Conectar a socket UNIX
int connect_unix_socket(const char *path) {
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) return -1;
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    
    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(sock);
        return -1;
    }
    return sock;
}

// Enviar mensaje IPC i3
int send_i3_message(int sock, uint32_t type, const char *payload) {
    uint32_t len = payload ? strlen(payload) : 0;
    uint8_t header[I3_IPC_MAGIC_LEN + sizeof(len) + sizeof(type)];
    
    memcpy(header, I3_IPC_MAGIC, I3_IPC_MAGIC_LEN);
    memcpy(header + I3_IPC_MAGIC_LEN, &len, sizeof(len));
    memcpy(header + I3_IPC_MAGIC_LEN + sizeof(len), &type, sizeof(type));
    
    if (write(sock, header, sizeof(header)) != sizeof(header)) return -1;
    if (len > 0 && write(sock, payload, len) != (ssize_t)len) return -1;
    
    return 0;
}

// Enviar pausa/reproducción a mpv con reintentos si el socket no está listo en el arranque
void set_mpv_pause(bool pause_val) {
    int sock = -1;
    int retries = 30;
    while (retries > 0) {
        sock = connect_unix_socket(MPV_SOCKET);
        if (sock >= 0) break;
        usleep(100000); // Esperar 100ms
        retries--;
    }
    if (sock < 0) return;
    
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "{\"command\": [\"set_property\", \"pause\", %s]}\n", pause_val ? "true" : "false");
    
    write(sock, cmd, strlen(cmd));
    close(sock);
}

// Enviar comando loadfile a mpv para hot-reload instantaneo
// Retorna 0 en exito, 1 si no se pudo conectar al socket
int send_mpv_loadfile(const char *path) {
    int sock = connect_unix_socket(MPV_SOCKET);
    if (sock < 0) return 1;

    char cmd[4096];
    snprintf(cmd, sizeof(cmd),
        "{\"command\": [\"loadfile\", \"%s\", \"replace\"]}\n", path);

    write(sock, cmd, strlen(cmd));

    // Leer respuesta para confirmar que mpv la procesó
    char resp[512];
    ssize_t n = read(sock, resp, sizeof(resp) - 1);
    close(sock);

    if (n > 0) {
        resp[n] = '\0';
        // Verificar que no hubo error en la respuesta JSON
        if (strstr(resp, "\"error\":\"success\"") || strstr(resp, "\"error\": \"success\"")) {
            return 0;
        }
    }
    return 1;
}


// Buscar de forma robusta la cadena "focused": true independiente de espacios
const char *find_focused_node(const char *json) {
    const char *ptr = json;
    while ((ptr = strstr(ptr, "\"focused\""))) {
        const char *p = ptr + 9;
        while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
        if (*p != ':') {
            ptr++;
            continue;
        }
        p++;
        while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
        if (strncmp(p, "true", 4) == 0) {
            return ptr;
        }
        ptr++;
    }
    return NULL;
}

// Extraer entero del JSON de forma robusta independiente de espacios
long get_json_int_value(const char *block, const char *key) {
    const char *ptr = strstr(block, key);
    if (!ptr) return -1;
    
    const char *p = ptr + strlen(key);
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    if (*p != ':') return -1;
    p++;
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    
    if (strncmp(p, "null", 4) == 0) return -1;
    
    long val = 0;
    if (sscanf(p, "%ld", &val) == 1) {
        return val;
    }
    return -1;
}

// Extraer cadena del JSON de forma robusta independiente de espacios
void get_json_string_value(const char *block, const char *key, char *dest, size_t dest_len) {
    dest[0] = '\0';
    const char *ptr = strstr(block, key);
    if (!ptr) return;
    
    const char *p = ptr + strlen(key);
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    if (*p != ':') return;
    p++;
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    
    if (*p == '"') {
        p++;
        size_t i = 0;
        while (*p && *p != '"' && i < dest_len - 1) {
            dest[i++] = *p++;
        }
        dest[i] = '\0';
    }
}

// Retroceder para encontrar el inicio del workspace actual
const char *find_parent_workspace(const char *json, const char *focused) {
    const char *ptr = focused;
    while (ptr > json) {
        if (strncmp(ptr, "\"type\"", 6) == 0) {
            const char *p = ptr + 6;
            while (*p == ' ' || *p == '\t' || *p == ':') p++;
            if (strncmp(p, "\"workspace\"", 11) == 0) {
                return ptr;
            }
        }
        ptr--;
    }
    return json;
}

// Encontrar el fin del workspace actual balanceando las llaves { } retrocediendo primero a su apertura
const char *find_workspace_end_by_brackets(const char *json_start, const char *workspace_start) {
    const char *p = workspace_start;
    while (p > json_start && *p != '{') p--;
    if (p <= json_start) return NULL;
    
    int depth = 1;
    const char *ptr = p + 1;
    while (*ptr && depth > 0) {
        if (*ptr == '{') depth++;
        else if (*ptr == '}') depth--;
        ptr++;
    }
    return ptr;
}

// Obtener propiedades de la ventana retrocediendo hasta su '{' de forma segura
void get_window_properties(const char *block_start, const char *window_ptr, char *floating_dest, size_t floating_len, long *fullscreen_mode_dest) {
    *fullscreen_mode_dest = 0;
    floating_dest[0] = '\0';
    
    const char *p = window_ptr;
    int depth = 0;
    while (p > block_start) {
        if (*p == '}') depth++;
        if (*p == '{') {
            if (depth == 0) {
                // Encontramos el objeto de la ventana actual.
                // Copiar un bloque amplio de 2048 bytes para asegurar floating y fullscreen_mode
                size_t max_len = strlen(p);
                size_t c_len = 2048;
                if (c_len > max_len) {
                    c_len = max_len;
                }
                char *sub = malloc(c_len + 1);
                if (sub) {
                    strncpy(sub, p, c_len);
                    sub[c_len] = '\0';
                    
                    get_json_string_value(sub, "\"floating\"", floating_dest, floating_len);
                    *fullscreen_mode_dest = get_json_int_value(sub, "\"fullscreen_mode\"");
                    free(sub);
                }
                break;
            }
            depth--;
        }
        p--;
    }
}

// Consultar el árbol completo y procesarlo
void query_and_process_tree(const char *i3_socket_path, bool pause_on_window) {
    int sock = connect_unix_socket(i3_socket_path);
    if (sock < 0) return;
    
    if (send_i3_message(sock, 4, "") < 0) {
        close(sock);
        return;
    }
    
    uint8_t head[14];
    ssize_t n = read(sock, head, sizeof(head));
    if (n <= 0) {
        close(sock);
        return;
    }
    
    uint32_t payload_len;
    memcpy(&payload_len, head + I3_IPC_MAGIC_LEN, sizeof(payload_len));
    
    char *buffer = malloc(payload_len + 1);
    if (!buffer) {
        close(sock);
        return;
    }
    
    size_t total_read = 0;
    while (total_read < payload_len) {
        n = read(sock, buffer + total_read, payload_len - total_read);
        if (n <= 0) break;
        total_read += n;
    }
    
    if (total_read == payload_len) {
        buffer[payload_len] = '\0';
        
        const char *focused = find_focused_node(buffer);
        if (focused) {
            const char *workspace_start = find_parent_workspace(buffer, focused);
            const char *workspace_end = find_workspace_end_by_brackets(buffer, workspace_start);
            if (!workspace_end) {
                workspace_end = buffer + payload_len;
            }
            
            size_t block_len = workspace_end - workspace_start;
            char *workspace_block = malloc(block_len + 1);
            if (workspace_block) {
                strncpy(workspace_block, workspace_start, block_len);
                workspace_block[block_len] = '\0';
                
                // Contar ventanas mosaico y buscar fullscreen real de ventana
                long tiling_count = 0;
                long has_fullscreen = 0;
                
                // Buscar ventanas en el bloque del workspace usando la clave estricta con dos puntos "window":
                const char *win_ptr = workspace_block;
                while ((win_ptr = strstr(win_ptr, "\"window\""))) {
                    const char *p = win_ptr + 8;
                    while (*p == ' ' || *p == '\t') p++;
                    if (*p != ':') {
                        win_ptr++;
                        continue;
                    }
                    
                    long win_id = get_json_int_value(win_ptr, "\"window\"");
                    if (win_id > 0) {
                        char floating[32] = "";
                        long win_fs = 0;
                        get_window_properties(workspace_block, win_ptr, floating, sizeof(floating), &win_fs);
                        
                        if (win_fs > 0) {
                            has_fullscreen = 1;
                        }
                        
                        // Si no es flotante, es tiling (mosaico)
                        if (strcmp(floating, "auto_on") != 0 && strcmp(floating, "user_on") != 0) {
                            tiling_count++;
                        }
                    }
                    win_ptr++;
                }
                
                // Decision
                bool should_pause = false;
                if (has_fullscreen > 0) {
                    should_pause = true;
                } else if (pause_on_window && tiling_count > 0) {
                    should_pause = true;
                }
                
                set_mpv_pause(should_pause);
                free(workspace_block);
            }
        } else {
            set_mpv_pause(false);
        }
    }
    
    free(buffer);
    close(sock);
}

// Obtener ruta del socket de i3wm de forma dinamica y robusta
const char *get_i3_socket_path(void) {
    static char path[512];
    const char *env_path = getenv("I3SOCK");
    if (env_path && strlen(env_path) > 0) {
        strncpy(path, env_path, sizeof(path) - 1);
        path[sizeof(path) - 1] = '\0';
        return path;
    }
    
    FILE *fp = popen("i3 --get-socketpath 2>/dev/null", "r");
    if (fp) {
        if (fgets(path, sizeof(path) - 1, fp)) {
            size_t len = strlen(path);
            if (len > 0 && path[len - 1] == '\n') {
                path[len - 1] = '\0';
            }
            pclose(fp);
            if (strlen(path) > 0) {
                return path;
            }
        } else {
            pclose(fp);
        }
    }
    
    return "/run/user/1000/i3/ipc-socket";
}

int main(int argc, char *argv[]) {
    signal(SIGPIPE, SIG_IGN);

    // Modo --loadfile <ruta>: hot-reload instantaneo, luego salir
    if (argc == 3 && strcmp(argv[1], "--loadfile") == 0) {
        int result = send_mpv_loadfile(argv[2]);
        return result;
    }

    // Modo daemon: monitorear i3wm y pausar/reanudar mpv segun ventanas
    const char *i3_socket_path = get_i3_socket_path();

    bool pause_on_window = true;
    const char *env_pause = getenv("LIVE_WP_PAUSE_ON_WINDOW");
    if (env_pause && strcmp(env_pause, "false") == 0) {
        pause_on_window = false;
    }

    char buffer[4096];
    query_and_process_tree(i3_socket_path, pause_on_window);

    while (true) {
        int i3_sock = connect_unix_socket(i3_socket_path);
        if (i3_sock < 0) {
            sleep(2);
            continue;
        }

        if (send_i3_message(i3_sock, I3_IPC_SUBSCRIBE, "[\"window\", \"workspace\"]") < 0) {
            close(i3_sock);
            sleep(2);
            continue;
        }

        while (true) {
            uint8_t head[14];
            ssize_t n = read(i3_sock, head, sizeof(head));
            if (n <= 0) break;

            uint32_t payload_len;
            memcpy(&payload_len, head + I3_IPC_MAGIC_LEN, sizeof(payload_len));

            size_t total_read = 0;
            while (total_read < payload_len) {
                size_t to_read = (payload_len - total_read) > sizeof(buffer)
                    ? sizeof(buffer) : (payload_len - total_read);
                n = read(i3_sock, buffer, to_read);
                if (n <= 0) break;
                total_read += n;
            }
            if (n <= 0) break;

            query_and_process_tree(i3_socket_path, pause_on_window);
        }

        close(i3_sock);
        sleep(1);
    }

    return 0;
}
