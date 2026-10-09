/*
 * Waybar module for SPlayer (https://github.com/SPlayer-Dev/SPlayer).
 * Polls SPlayer's local control API and emits Waybar JSON output.
 *
 * Build:
 *   gcc -O2 -Wall -o waybar-splayer waybar-splayer.c \
 *       $(pkg-config --cflags --libs libcurl jansson)
 */
#include <curl/curl.h>
#include <jansson.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BASE_URL "http://127.0.0.1:25884"
#define MAX_LABEL 40

typedef struct {
    char *data;
    size_t size;
} Buffer;

static size_t write_cb(void *contents, size_t size, size_t nmemb, void *userp)
{
    Buffer *buf = userp;
    size_t total = size * nmemb;
    char *ptr = realloc(buf->data, buf->size + total + 1);
    if (!ptr)
        return 0;
    buf->data = ptr;
    memcpy(buf->data + buf->size, contents, total);
    buf->size += total;
    buf->data[buf->size] = '\0';
    return total;
}

static char *fetch_json(const char *path)
{
    CURL *curl = curl_easy_init();
    if (!curl)
        return NULL;

    Buffer buf = {.data = malloc(1), .size = 0};
    buf.data[0] = '\0';

    char url[256];
    snprintf(url, sizeof(url), BASE_URL "%s", path);

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 2L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 1L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

    CURLcode res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        free(buf.data);
        return NULL;
    }
    return buf.data;
}

/* Escape text for embedding in the pango tooltip */
static char *xml_escape(const char *s)
{
    if (!s)
        return strdup("");
    size_t cap = strlen(s) * 6 + 1;
    char *out = malloc(cap);
    size_t j = 0;
    for (size_t i = 0; s[i] && j + 8 < cap; i++) {
        switch (s[i]) {
        case '&':  j += snprintf(out + j, cap - j, "&amp;");   break;
        case '<':  j += snprintf(out + j, cap - j, "&lt;");    break;
        case '>':  j += snprintf(out + j, cap - j, "&gt;");    break;
        case '"':  j += snprintf(out + j, cap - j, "&quot;");  break;
        case '\'': j += snprintf(out + j, cap - j, "&apos;");  break;
        default:   out[j++] = s[i];
        }
    }
    out[j] = '\0';
    return out;
}

static void fmt_time(long ms, char *out, size_t n)
{
    if (ms < 0)
        ms = 0;
    snprintf(out, n, "%d:%02d", (int)(ms / 60000), (int)((ms / 1000) % 60));
}

static long json_num(json_t *obj, const char *key)
{
    json_t *v = json_object_get(obj, key);
    if (json_is_real(v))
        return (long)json_real_value(v);
    if (json_is_integer(v))
        return (long)json_integer_value(v);
    return 0;
}

static const char *json_str(json_t *obj, const char *key)
{
    json_t *v = json_object_get(obj, key);
    return v && json_is_string(v) ? json_string_value(v) : "";
}

int main(void)
{
    char *body = fetch_json("/api/control/song-info");
    if (!body) {
        /* Empty output hides the module when SPlayer is not running */
        printf("\n");
        return 0;
    }

    json_t *root = json_loads(body, 0, NULL);
    free(body);
    json_t *data = root ? json_object_get(root, "data") : NULL;

    if (!root || !json_is_object(data)) {
        json_decref(root);
        printf("\n");
        return 0;
    }

    int playing = json_is_true(json_object_get(data, "playStatus"));
    const char *name = json_str(data, "name");
    const char *artist = "";
    const char *album = "";
    long current = json_num(data, "currentTime");
    long total = json_num(data, "duration");

    json_t *artists = json_object_get(data, "artists");
    if (json_is_array(artists) && json_array_size(artists) > 0) {
        artist = json_str(json_array_get(artists, 0), "name");
    }
    json_t *album_obj = json_object_get(data, "album");
    if (json_is_object(album_obj)) {
        album = json_str(album_obj, "name");
    }

    char cur_s[16] = "0:00", tot_s[16] = "0:00";
    fmt_time(current, cur_s, sizeof(cur_s));
    fmt_time(total, tot_s, sizeof(tot_s));

    char label[256];
    if (artist[0])
        snprintf(label, sizeof(label), "%s %s - %s", playing ? "\xe2\x96\xb6" : "\xe2\x8f\xb8",
                 artist, name);
    else
        snprintf(label, sizeof(label), "%s %s", playing ? "\xe2\x96\xb6" : "\xe2\x8f\xb8", name);

    /* Truncate to MAX_LABEL unicode-aware so multi-byte chars stay intact */
    size_t len = strlen(label);
    if (len > MAX_LABEL * 4) {
        size_t cut = MAX_LABEL * 4;
        while (cut > 0 && (label[cut] & 0xC0) == 0x80)
            cut--;
        strcpy(label + cut - 3, "\xe2\x80\xa6");
    }

    char *t_esc = xml_escape(name);
    char *a_esc = xml_escape(artist);
    char *al_esc = xml_escape(album);

    printf("{\"text\": \"%s\", \"alt\": \"%s\", \"class\": \"%s\", "
           "\"tooltip\": \"<big><b>%s</b></big>\\n%s - %s\\n%s / %s\"}\n",
           label, playing ? "playing" : "paused", playing ? "playing" : "paused",
           t_esc, a_esc, al_esc, cur_s, tot_s);

    free(t_esc);
    free(a_esc);
    free(al_esc);
    json_decref(root);
    return 0;
}
