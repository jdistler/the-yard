/* tvnet: the network side of Partycade TV (games/tv/PLAN.md), for Home's TV guide (games/love/home/tv.lua).
 * The cabinet has no TLS outside libavformat (busybox wget has none), so every fetch goes through its AVIO.
 *
 *   tvnet sync CONF NAME LISTDIR EPGDIR
 *       CONF: lines "name<TAB>server<TAB>username<TAB>password" (/data/tv/account.conf, mode 600; read from the
 *       file so the password is never on a command line, where ps shows it). One playlist (an Xtream panel, or Skywave's syndication proxy: curated groups and channels):
 *       the handshake (sets the clock from the server's, the cabinet starts at 1970), then
 *         LISTDIR/groups.tsv     category_id  name
 *         LISTDIR/channels.tsv   category_id  stream_id  name  epg_channel_id  logo_url
 *         EPGDIR/epg.tsv         epg_channel_id  start  stop  title  description   (UTC seconds; the panel's
 *                                XMLTV, streamed and cut to the listed channels, from now to 12 h ahead;
 *                                descriptions only for the next 4 h)
 *       Each file is written beside and renamed into place. Progress on stdout, a line per step:
 *         ok handshake <server time> | groups N | channels N | epg N | error <step> <message>
 *   tvnet logos LISTFILE OUTDIR W H
 *       Each line of LISTFILE: "key url". The logo is fetched, decoded (PNG, JPEG, GIF, WebP, BMP) and scaled
 *       to fit W x H, then written as OUTDIR/key.rgba: "RGBA", width and height (16-bit little-endian each),
 *       then the pixels. A logo that cannot be had leaves OUTDIR/key.fail. stdout: "logo key ok|fail|have".
 *
 * Rockchip's FFmpeg 4.1.3 on the cabinet does not match stock 4.1's struct layouts everywhere (AVStream,
 * AVCodecParameters: see tvplay.c); tvnet uses only AVIO, AVPacket, AVFrame and function calls. */
#include <libavcodec/avcodec.h>
#include <libavformat/avio.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
#include <zlib.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

static void say(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    putchar('\n');
    fflush(stdout);
}

/* ------------------------------------------------------------------ fetching */

static AVIOContext *open_url(const char *url, int gzip, char *err, size_t errn)
{
    AVDictionary *o = NULL;
    av_dict_set(&o, "rw_timeout", "15000000", 0);
    av_dict_set(&o, "timeout", "15000000", 0);
    av_dict_set(&o, "user_agent", "Partycade/1.0", 0);
    if (gzip) av_dict_set(&o, "headers", "Accept-Encoding: gzip\r\n", 0);
    AVIOContext *pb = NULL;
    int r = avio_open2(&pb, url, AVIO_FLAG_READ, NULL, &o);
    av_dict_free(&o);
    if (r < 0) {
        av_strerror(r, err, errn);
        return NULL;
    }
    return pb;
}

typedef struct { char *p; size_t n, cap; } Buf;

static int buf_add(Buf *b, const void *d, size_t n)
{
    if (b->n + n + 1 > b->cap) {
        size_t c = b->cap ? b->cap * 2 : 65536;
        while (c < b->n + n + 1) c *= 2;
        char *q = realloc(b->p, c);
        if (!q) return -1;
        b->p = q;
        b->cap = c;
    }
    memcpy(b->p + b->n, d, n);
    b->n += n;
    b->p[b->n] = 0;
    return 0;
}

static int fetch_once(const char *url, Buf *out, size_t max, char *err, size_t errn);

/* A whole body into memory (the API's JSON, a logo), up to max bytes; up to three tries, 2 s apart (the
 * syndication proxy answers an occasional 5xx). */
static int fetch(const char *url, Buf *out, size_t max, char *err, size_t errn)
{
    for (int i = 0; i < 3; i++) {
        out->n = 0;
        if (fetch_once(url, out, max, err, errn) == 0) return 0;
        if (!strcmp(err, "too big")) return -1;
        if (i < 2) sleep(2);
    }
    return -1;
}

static int fetch_once(const char *url, Buf *out, size_t max, char *err, size_t errn)
{
    AVIOContext *pb = open_url(url, 0, err, errn);
    if (!pb) return -1;
    unsigned char tmp[16384];
    for (;;) {
        int n = avio_read(pb, tmp, sizeof tmp);
        if (n == AVERROR_EOF || n == 0) break;
        if (n < 0) {
            av_strerror(n, err, errn);
            avio_closep(&pb);
            return -1;
        }
        if (out->n + n > max || buf_add(out, tmp, n) < 0) {
            snprintf(err, errn, "too big");
            avio_closep(&pb);
            return -1;
        }
    }
    avio_closep(&pb);
    if (!out->p) buf_add(out, "", 0);
    return 0;
}

/* ------------------------------------------------------------------ JSON (just enough) */

/* The Xtream API's answers are arrays of flat objects: each object's scalar values are handed over as
 * strings (numbers and true/false/null as written); nested values are skipped. */
typedef struct { const char *s, *e; } J;

static void ws(J *j) { while (j->s < j->e && (*j->s == ' ' || *j->s == '\n' || *j->s == '\r' || *j->s == '\t')) j->s++; }

static void put_utf8(Buf *b, unsigned c)
{
    char u[4];
    int n;
    if (c < 0x80) { u[0] = c; n = 1; }
    else if (c < 0x800) { u[0] = 0xC0 | c >> 6; u[1] = 0x80 | (c & 63); n = 2; }
    else if (c < 0x10000) { u[0] = 0xE0 | c >> 12; u[1] = 0x80 | (c >> 6 & 63); u[2] = 0x80 | (c & 63); n = 3; }
    else { u[0] = 0xF0 | c >> 18; u[1] = 0x80 | (c >> 12 & 63); u[2] = 0x80 | (c >> 6 & 63); u[3] = 0x80 | (c & 63); n = 4; }
    buf_add(b, u, n);
}

static unsigned hex4(const char *p)
{
    unsigned v = 0;
    for (int i = 0; i < 4; i++) {
        char c = p[i];
        v = v * 16 + (c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : 0);
    }
    return v;
}

/* A string at j->s (on its quote) into out (if given); 0 or -1. */
static int jstring(J *j, Buf *out)
{
    if (j->s >= j->e || *j->s != '"') return -1;
    j->s++;
    while (j->s < j->e && *j->s != '"') {
        if (*j->s == '\\' && j->s + 1 < j->e) {
            char c = j->s[1];
            j->s += 2;
            if (!out) { if (c == 'u') j->s += 4; continue; }
            switch (c) {
            case 'n': case 'r': case 't': buf_add(out, " ", 1); break;
            case 'b': case 'f': break;
            case 'u':
                if (j->s + 4 <= j->e) {
                    unsigned u = hex4(j->s);
                    j->s += 4;
                    if (u >= 0xD800 && u < 0xDC00 && j->s + 6 <= j->e && j->s[0] == '\\' && j->s[1] == 'u') {
                        unsigned lo = hex4(j->s + 2);
                        if (lo >= 0xDC00 && lo < 0xE000) { u = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00); j->s += 6; }
                    }
                    put_utf8(out, u);
                }
                break;
            default: buf_add(out, &c, 1);
            }
        } else {
            const char *q = j->s;
            while (q < j->e && *q != '"' && *q != '\\') q++;
            if (out) {
                /* Tabs and newlines would break the TSV lines. */
                for (const char *r = j->s; r < q; r++) buf_add(out, (*r == '\t' || *r == '\n' || *r == '\r') ? " " : r, 1);
            }
            j->s = q;
        }
    }
    if (j->s >= j->e) return -1;
    j->s++;
    return 0;
}

static int jskip(J *j);

static int jskip_container(J *j, char open, char close)
{
    (void)open;
    j->s++;
    for (;;) {
        ws(j);
        if (j->s >= j->e) return -1;
        if (*j->s == close) { j->s++; return 0; }
        if (*j->s == ',' || *j->s == ':') { j->s++; continue; }
        if (jskip(j) < 0) return -1;
    }
}

static int jskip(J *j)
{
    ws(j);
    if (j->s >= j->e) return -1;
    if (*j->s == '"') return jstring(j, NULL);
    if (*j->s == '{') return jskip_container(j, '{', '}');
    if (*j->s == '[') return jskip_container(j, '[', ']');
    while (j->s < j->e && *j->s != ',' && *j->s != '}' && *j->s != ']' && *j->s != ' ' && *j->s != '\n') j->s++;
    return 0;
}

#define MAXF 8
typedef struct { const char *keys[MAXF]; Buf val[MAXF]; int n; } Fields;

/* For each object in the top-level array: fields' values filled (empty when missing), then fn called. */
static int jarray(const char *s, size_t n, Fields *f, void (*fn)(Fields *, void *), void *ctx)
{
    J j = {s, s + n};
    ws(&j);
    if (j.s >= j.e || *j.s != '[') return -1;
    j.s++;
    int count = 0;
    Buf key = {0};
    for (;;) {
        ws(&j);
        if (j.s >= j.e) return -1;
        if (*j.s == ']') break;
        if (*j.s == ',') { j.s++; continue; }
        if (*j.s != '{') { if (jskip(&j) < 0) return -1; continue; }
        j.s++;
        for (int i = 0; i < f->n; i++) { f->val[i].n = 0; buf_add(&f->val[i], "", 0); }
        for (;;) {
            ws(&j);
            if (j.s >= j.e) return -1;
            if (*j.s == '}') { j.s++; break; }
            if (*j.s == ',') { j.s++; continue; }
            key.n = 0;
            if (jstring(&j, &key) < 0) return -1;
            ws(&j);
            if (j.s >= j.e || *j.s != ':') return -1;
            j.s++;
            ws(&j);
            int which = -1;
            for (int i = 0; i < f->n; i++) if (key.p && !strcmp(key.p, f->keys[i])) which = i;
            if (which >= 0 && *j.s == '"') {
                if (jstring(&j, &f->val[which]) < 0) return -1;
            } else if (which >= 0 && *j.s != '{' && *j.s != '[') {
                const char *a = j.s;
                if (jskip(&j) < 0) return -1;
                if (!(j.s - a == 4 && !memcmp(a, "null", 4))) buf_add(&f->val[which], a, j.s - a);
            } else if (jskip(&j) < 0) return -1;
        }
        fn(f, ctx);
        count++;
    }
    free(key.p);
    return count;
}

/* A number value of a key anywhere in a JSON text ("key": 123 or "key": "123"). */
static long long jfind_num(const char *s, const char *key)
{
    char pat[64];
    snprintf(pat, sizeof pat, "\"%s\"", key);
    const char *p = strstr(s, pat);
    if (!p) return -1;
    p += strlen(pat);
    while (*p == ' ' || *p == ':' || *p == '"') p++;
    return strtoll(p, NULL, 10);
}

/* ------------------------------------------------------------------ files */

typedef struct { FILE *f; char path[512], tmp[520]; } Out;

static int out_open(Out *o, const char *dir, const char *name)
{
    snprintf(o->path, sizeof o->path, "%s/%s", dir, name);
    snprintf(o->tmp, sizeof o->tmp, "%s.new", o->path);
    o->f = fopen(o->tmp, "w");
    return o->f ? 0 : -1;
}

static int out_close(Out *o)
{
    if (fclose(o->f) != 0) { unlink(o->tmp); return -1; }
    return rename(o->tmp, o->path);
}

static void mkdirs(const char *d)
{
    char p[512];
    snprintf(p, sizeof p, "%s", d);
    for (char *q = p + 1; *q; q++) if (*q == '/') { *q = 0; mkdir(p, 0755); *q = '/'; }
    mkdir(p, 0755);
}

/* ------------------------------------------------------------------ the channel set (for the guide) */

#define HSLOTS 8192
static char *ids[HSLOTS];

static unsigned hstr(const char *s, size_t n)
{
    unsigned h = 2166136261u;
    for (size_t i = 0; i < n; i++) h = (h ^ (unsigned char)s[i]) * 16777619u;
    return h;
}

static void id_add(const char *s)
{
    if (!*s) return;
    unsigned h = hstr(s, strlen(s)) % HSLOTS;
    for (int k = 0; k < HSLOTS; k++, h = (h + 1) % HSLOTS) {
        if (!ids[h]) { ids[h] = strdup(s); return; }
        if (!strcmp(ids[h], s)) return;
    }
}

static int id_has(const char *s, size_t n)
{
    unsigned h = hstr(s, n) % HSLOTS;
    for (int k = 0; k < HSLOTS; k++, h = (h + 1) % HSLOTS) {
        if (!ids[h]) return 0;
        if (strlen(ids[h]) == n && !memcmp(ids[h], s, n)) return 1;
    }
    return 0;
}

/* ------------------------------------------------------------------ sync */

static void tsv(FILE *f, Buf *v, int last)
{
    fwrite(v->p ? v->p : "", 1, v->n, f);
    fputc(last ? '\n' : '\t', f);
}

static void on_group(Fields *f, void *ctx) { FILE *o = ctx; tsv(o, &f->val[0], 0); tsv(o, &f->val[1], 1); }

static void on_stream(Fields *f, void *ctx)
{
    FILE *o = ctx;
    for (int i = 0; i < 5; i++) tsv(o, &f->val[i], i == 4);
    if (f->val[3].p) id_add(f->val[3].p);
}

/* Days since 1970-01-01 of a civil date (Howard Hinnant's algorithm). */
static long long days_civil(int y, int m, int d)
{
    y -= m <= 2;
    long long era = (y >= 0 ? y : y - 399) / 400;
    unsigned yoe = (unsigned)(y - era * 400);
    unsigned doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
    unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + (long long)doe - 719468;
}

/* "20261027230500 +0000" -> UTC seconds. */
static long long xmltv_time(const char *s)
{
    int v[6], len[6] = {4, 2, 2, 2, 2, 2};
    for (int i = 0; i < 6; i++) {
        v[i] = 0;
        for (int k = 0; k < len[i]; k++, s++) { if (*s < '0' || *s > '9') return -1; v[i] = v[i] * 10 + (*s - '0'); }
    }
    long long t = days_civil(v[0], v[1], v[2]) * 86400 + v[3] * 3600 + v[4] * 60 + v[5];
    while (*s == ' ') s++;
    if ((*s == '+' || *s == '-') && strlen(s) >= 5) {
        int off = ((s[1] - '0') * 10 + (s[2] - '0')) * 3600 + ((s[3] - '0') * 10 + (s[4] - '0')) * 60;
        t -= *s == '+' ? off : -off;
    }
    return t;
}

/* An attribute's value inside a tag [a, e): copied into out (n bytes max); its length or -1. */
static int attr(const char *a, const char *e, const char *name, char *out, int n)
{
    size_t nl = strlen(name);
    for (const char *p = a; p + nl + 2 < e; p++) {
        if ((p == a || p[-1] == ' ') && !memcmp(p, name, nl) && p[nl] == '=' && p[nl + 1] == '"') {
            const char *v = p + nl + 2, *q = memchr(v, '"', e - v);
            if (!q) return -1;
            int l = q - v < n - 1 ? (int)(q - v) : n - 1;
            memcpy(out, v, l);
            out[l] = 0;
            return l;
        }
    }
    return -1;
}

/* Text of <tag ...>...</tag> inside [a, e), XML entities decoded, tabs and newlines made spaces, cut to max. */
static void elem_text(const char *a, const char *e, const char *tag, Buf *out, int max)
{
    char open[32], close[32];
    snprintf(open, sizeof open, "<%s", tag);
    snprintf(close, sizeof close, "</%s>", tag);
    out->n = 0;
    buf_add(out, "", 0);
    const char *p = a;
    size_t ol = strlen(open);
    for (;;) {
        p = memchr(p, '<', e - p);
        if (!p || p + ol >= e) return;
        if (!memcmp(p, open, ol) && (p[ol] == '>' || p[ol] == ' ')) break;
        p++;
    }
    const char *s = memchr(p, '>', e - p);
    if (!s) return;
    s++;
    const char *q = s;
    size_t cl = strlen(close);
    while (q + cl <= e && memcmp(q, close, cl)) q++;
    if (q + cl > e) return;
    for (const char *r = s; r < q && (int)out->n < max; r++) {
        if (*r == '&') {
            static const struct { const char *e; char c; } ent[] = {{"&amp;", '&'}, {"&lt;", '<'}, {"&gt;", '>'}, {"&quot;", '"'}, {"&apos;", '\''}};
            int done = 0;
            for (unsigned k = 0; k < sizeof ent / sizeof ent[0]; k++) {
                size_t l = strlen(ent[k].e);
                if (r + l <= q && !memcmp(r, ent[k].e, l)) { buf_add(out, &ent[k].c, 1); r += l - 1; done = 1; break; }
            }
            if (!done && r + 2 < q && r[1] == '#') {
                const char *z = memchr(r, ';', q - r);
                if (z) { put_utf8(out, (unsigned)(r[2] == 'x' ? strtoul(r + 3, NULL, 16) : strtoul(r + 2, NULL, 10))); r = z; done = 1; }
            }
            if (!done) buf_add(out, "&", 1);
        } else if (*r == '\t' || *r == '\n' || *r == '\r') {
            if (out->n && out->p[out->n - 1] != ' ') buf_add(out, " ", 1);
        } else {
            buf_add(out, r, 1);
        }
    }
    /* Never end mid-character after a cut. */
    while (out->n && ((unsigned char)out->p[out->n - 1] & 0xC0) == 0x80) out->n--;
    if (out->n && ((unsigned char)out->p[out->n - 1] & 0xC0) == 0xC0) out->n--;
    out->p[out->n] = 0;
}

/* A gzip or plain stream, read through. */
typedef struct { AVIOContext *pb; z_stream z; int gz, zinit, eof; unsigned char in[65536]; } Src;

static int src_read(Src *s, unsigned char *dst, int n)
{
    if (!s->gz) {
        int r = avio_read(s->pb, dst, n);
        return r == AVERROR_EOF ? 0 : r;
    }
    s->z.next_out = dst;
    s->z.avail_out = n;
    while (s->z.avail_out == (unsigned)n) {
        if (s->z.avail_in == 0 && !s->eof) {
            int r = avio_read(s->pb, s->in, sizeof s->in);
            if (r == AVERROR_EOF || r == 0) s->eof = 1;
            else if (r < 0) return r;
            else { s->z.next_in = s->in; s->z.avail_in = r; }
        }
        int z = inflate(&s->z, Z_NO_FLUSH);
        if (z == Z_STREAM_END) {
            /* Concatenated members are allowed in gzip. */
            if (s->z.avail_in == 0 && s->eof) break;
            inflateReset(&s->z);
        } else if (z != Z_OK && z != Z_BUF_ERROR) return -1;
        if (s->eof && s->z.avail_in == 0 && s->z.avail_out == (unsigned)n) break;
    }
    return n - (int)s->z.avail_out;
}

static int epg(const char *server, const char *user, const char *pass, const char *dir, long long now)
{
    char url[1024], err[256];
    snprintf(url, sizeof url, "%s/xmltv.php?username=%s&password=%s", server, user, pass);
    Src s;
    memset(&s, 0, sizeof s);
    s.pb = open_url(url, 1, err, sizeof err);
    if (!s.pb) { say("error epg %s", err); return -1; }
    /* Gzip if the body starts with its magic (libavformat may have inflated it already). */
    unsigned char head[2];
    int hn = avio_read(s.pb, head, 2);
    if (hn < 2) { say("error epg empty"); avio_closep(&s.pb); return -1; }
    Buf b = {0};
    if (head[0] == 0x1f && head[1] == 0x8b) {
        s.gz = 1;
        if (inflateInit2(&s.z, 16 + MAX_WBITS) != Z_OK) { say("error epg zlib"); return -1; }
        s.zinit = 1;
        memcpy(s.in, head, 2);
        s.z.next_in = s.in;
        s.z.avail_in = 2;
    } else {
        buf_add(&b, head, 2);
    }
    Out o;
    if (out_open(&o, dir, "epg.tsv") < 0) { say("error epg cannot write %s", dir); return -1; }
    Buf title = {0}, desc = {0};
    long long until = now + 12 * 3600, desc_until = now + 4 * 3600;
    int count = 0, bad = 0;
    size_t pos = 0;
    for (;;) {
        /* The next whole <programme ...>...</programme> in the buffer, reading more as needed. */
        char *p = b.p ? strstr(b.p + pos, "<programme") : NULL;
        char *q = p ? strstr(p, "</programme>") : NULL;
        if (!q) {
            /* Keep the unfinished tail (from the last "<programme", or a few bytes) and read on. */
            size_t keep_from = p ? (size_t)(p - b.p) : (b.n > 16 ? b.n - 16 : 0);
            memmove(b.p, b.p + keep_from, b.n - keep_from);
            b.n -= keep_from;
            b.p[b.n] = 0;
            pos = 0;
            unsigned char tmp[65536];
            int r = src_read(&s, tmp, sizeof tmp);
            if (r < 0) { bad = 1; break; }
            if (r == 0) break;
            buf_add(&b, tmp, r);
            continue;
        }
        const char *tag_end = memchr(p, '>', q - p);
        pos = (q - b.p) + 12;
        if (!tag_end) continue;
        char ch[256], st[40], sp[40];
        int cl = attr(p, tag_end, "channel", ch, sizeof ch);
        if (cl <= 0 || !id_has(ch, cl)) continue;
        if (attr(p, tag_end, "start", st, sizeof st) < 0 || attr(p, tag_end, "stop", sp, sizeof sp) < 0) continue;
        long long t0 = xmltv_time(st), t1 = xmltv_time(sp);
        if (t0 < 0 || t1 <= now || t0 >= until) continue;
        elem_text(tag_end, q, "title", &title, 160);
        if (t0 < desc_until) elem_text(tag_end, q, "desc", &desc, 240);
        else { desc.n = 0; buf_add(&desc, "", 0); }
        fprintf(o.f, "%s\t%lld\t%lld\t%s\t%s\n", ch, t0, t1, title.p ? title.p : "", desc.p ? desc.p : "");
        count++;
    }
    if (s.zinit) inflateEnd(&s.z);
    avio_closep(&s.pb);
    free(b.p);
    free(title.p);
    free(desc.p);
    if (bad) { fclose(o.f); unlink(o.tmp); say("error epg read failed"); return -1; }
    if (out_close(&o) < 0) { say("error epg cannot write"); return -1; }
    say("epg %d", count);
    return 0;
}

static int sync_list(int argc, char **argv)
{
    if (argc < 6) { fprintf(stderr, "tvnet sync CONF NAME LISTDIR EPGDIR\n"); return 2; }
    const char *listdir = argv[4], *epgdir = argv[5];
    static char line[2048];
    char *server = NULL, *user = NULL, *pass = NULL;
    FILE *cf = fopen(argv[2], "r");
    while (cf && fgets(line, sizeof line, cf)) {
        line[strcspn(line, "\r\n")] = 0;
        char *f[4], *p = line;
        int k = 0;
        for (; k < 4 && p; k++) { f[k] = p; p = strchr(p, '\t'); if (p) *p++ = 0; }
        if (k == 4 && line[0] != '#' && !strcmp(f[0], argv[3])) { server = f[1]; user = f[2]; pass = f[3]; break; }
    }
    if (cf) fclose(cf);
    if (!server) { say("error handshake no playlist %s in %s", argv[3], argv[2]); return 1; }
    mkdirs(listdir);
    mkdirs(epgdir);
    char url[1024], err[256];
    Buf b = {0};
    snprintf(url, sizeof url, "%s/player_api.php?username=%s&password=%s", server, user, pass);
    if (fetch(url, &b, 1 << 20, err, sizeof err) < 0) { say("error handshake %s", err); return 1; }
    if (!strstr(b.p, "\"auth\":1") && !strstr(b.p, "\"auth\": 1") && !strstr(b.p, "\"auth\":\"1\"")) {
        say("error handshake login refused");
        return 1;
    }
    long long now = jfind_num(b.p, "timestamp_now");
    struct timeval tv;
    gettimeofday(&tv, NULL);
    if (now > 1700000000) {
        /* The cabinet has no clock battery: it starts at 1970 every power-on. */
        if (llabs(now - (long long)tv.tv_sec) > 30) {
            struct timeval set = {(time_t)now, 0};
            settimeofday(&set, NULL);
        }
    } else {
        now = tv.tv_sec;
    }
    say("ok handshake %lld", now);

    Fields f = {{"category_id", "category_name"}, {{0}}, 2};
    b.n = 0;
    snprintf(url, sizeof url, "%s/player_api.php?username=%s&password=%s&action=get_live_categories", server, user, pass);
    if (fetch(url, &b, 4 << 20, err, sizeof err) < 0) { say("error groups %s", err); return 1; }
    Out o;
    if (out_open(&o, listdir, "groups.tsv") < 0) { say("error groups cannot write"); return 1; }
    int n = jarray(b.p, b.n, &f, on_group, o.f);
    if (n < 0) { fclose(o.f); unlink(o.tmp); say("error groups bad answer"); return 1; }
    out_close(&o);
    say("groups %d", n);

    Fields g = {{"category_id", "stream_id", "name", "epg_channel_id", "stream_icon"}, {{0}}, 5};
    b.n = 0;
    snprintf(url, sizeof url, "%s/player_api.php?username=%s&password=%s&action=get_live_streams", server, user, pass);
    if (fetch(url, &b, 24 << 20, err, sizeof err) < 0) { say("error channels %s", err); return 1; }
    if (out_open(&o, listdir, "channels.tsv") < 0) { say("error channels cannot write"); return 1; }
    n = jarray(b.p, b.n, &g, on_stream, o.f);
    if (n < 0) { fclose(o.f); unlink(o.tmp); say("error channels bad answer"); return 1; }
    out_close(&o);
    free(b.p);
    say("channels %d", n);
    return epg(server, user, pass, epgdir, now) < 0 ? 1 : 0;
}

/* ------------------------------------------------------------------ logos */

static int logo(const char *url, const char *path, int bw, int bh, char *why, size_t whyn)
{
    Buf b = {0};
    if (fetch(url, &b, 4 << 20, why, whyn) < 0) return -1;
    const unsigned char *d = (const unsigned char *)b.p;
    enum AVCodecID id = AV_CODEC_ID_NONE;
    if (b.n > 8 && !memcmp(d, "\x89PNG", 4)) id = AV_CODEC_ID_PNG;
    else if (b.n > 3 && d[0] == 0xFF && d[1] == 0xD8) id = AV_CODEC_ID_MJPEG;
    else if (b.n > 6 && !memcmp(d, "GIF8", 4)) id = AV_CODEC_ID_GIF;
    else if (b.n > 12 && !memcmp(d, "RIFF", 4) && !memcmp(d + 8, "WEBP", 4)) id = AV_CODEC_ID_WEBP;
    else if (b.n > 2 && !memcmp(d, "BM", 2)) id = AV_CODEC_ID_BMP;
    if (id == AV_CODEC_ID_NONE) { snprintf(why, whyn, "not an image (%zu bytes)", b.n); free(b.p); return -1; }
    const AVCodec *c = avcodec_find_decoder(id);
    AVCodecContext *cx = c ? avcodec_alloc_context3(c) : NULL;
    AVPacket *pkt = av_packet_alloc();
    AVFrame *fr = av_frame_alloc();
    int ok = -1;
    if (!cx || !pkt || !fr || avcodec_open2(cx, c, NULL) < 0 || av_new_packet(pkt, (int)b.n) < 0) {
        snprintf(why, whyn, "no decoder");
        goto done;
    }
    memcpy(pkt->data, b.p, b.n);
    if (avcodec_send_packet(cx, pkt) < 0) { snprintf(why, whyn, "bad image"); goto done; }
    avcodec_send_packet(cx, NULL);
    if (avcodec_receive_frame(cx, fr) < 0 || fr->width <= 0 || fr->height <= 0) { snprintf(why, whyn, "bad image"); goto done; }
    double k = (double)bw / fr->width < (double)bh / fr->height ? (double)bw / fr->width : (double)bh / fr->height;
    if (k > 1) k = 1;              /* small logos are not blown up here (the GPU scales them) */
    int w = (int)(fr->width * k + 0.5), h = (int)(fr->height * k + 0.5);
    if (w < 1) w = 1;
    if (h < 1) h = 1;
    struct SwsContext *sws = sws_getContext(fr->width, fr->height, fr->format, w, h, AV_PIX_FMT_RGBA,
                                            SWS_AREA, NULL, NULL, NULL);
    if (!sws) { snprintf(why, whyn, "cannot scale"); goto done; }
    unsigned char *px = malloc((size_t)w * h * 4 + 8);
    uint8_t *dst[4] = {px + 8, NULL, NULL, NULL};
    int dls[4] = {w * 4, 0, 0, 0};
    sws_scale(sws, (const uint8_t *const *)fr->data, fr->linesize, 0, fr->height, dst, dls);
    sws_freeContext(sws);
    memcpy(px, "RGBA", 4);
    px[4] = w & 255; px[5] = w >> 8; px[6] = h & 255; px[7] = h >> 8;
    char tmp[600];
    snprintf(tmp, sizeof tmp, "%s.new", path);
    FILE *f = fopen(tmp, "wb");
    if (f && fwrite(px, 1, (size_t)w * h * 4 + 8, f) == (size_t)w * h * 4 + 8 && fclose(f) == 0 && rename(tmp, path) == 0) ok = 0;
    else { if (f) fclose(f); snprintf(why, whyn, "cannot write"); }
    free(px);
done:
    av_frame_free(&fr);
    av_packet_free(&pkt);
    avcodec_free_context(&cx);
    free(b.p);
    return ok;
}

static int logos(int argc, char **argv)
{
    if (argc < 6) { fprintf(stderr, "tvnet logos LISTFILE OUTDIR W H\n"); return 2; }
    FILE *l = fopen(argv[2], "r");
    if (!l) return 1;
    mkdirs(argv[3]);
    int bw = atoi(argv[4]), bh = atoi(argv[5]);
    char line[2048];
    while (fgets(line, sizeof line, l)) {
        char *sp = strchr(line, ' ');
        if (!sp) continue;
        *sp = 0;
        char *url = sp + 1;
        url[strcspn(url, "\r\n")] = 0;
        char path[600], fail[600], why[256] = "";
        snprintf(path, sizeof path, "%s/%s.rgba", argv[3], line);
        snprintf(fail, sizeof fail, "%s/%s.fail", argv[3], line);
        if (!access(path, F_OK)) { say("logo %s have", line); continue; }
        if (!access(fail, F_OK)) { say("logo %s fail", line); continue; }
        if (logo(url, path, bw, bh, why, sizeof why) == 0) say("logo %s ok", line);
        else {
            FILE *f = fopen(fail, "w");
            if (f) { fprintf(f, "%s\n", why); fclose(f); }
            say("logo %s fail", line);
        }
    }
    fclose(l);
    return 0;
}

/* tvnet get URL OUT: a public URL's body into OUT (written whole, then renamed into place), at most 2 MB.
 * Home's game-day data (games/love/home/utgame.lua: ESPN's public team endpoint). */
static int get(int argc, char **argv)
{
    if (argc < 4) return 2;
    Buf b = {0};
    char err[256] = "";
    if (fetch(argv[2], &b, 2 << 20, err, sizeof err) < 0) { printf("error %s\n", err); return 1; }
    char tmp[1024];
    snprintf(tmp, sizeof tmp, "%s.new", argv[3]);
    FILE *f = fopen(tmp, "wb");
    if (!f || fwrite(b.p, 1, b.n, f) != b.n) { if (f) fclose(f); printf("error write\n"); return 1; }
    fclose(f);
    rename(tmp, argv[3]);
    printf("ok %zu\n", b.n);
    return 0;
}

int main(int argc, char **argv)
{
    if (nice(10) < 0) { /* the guide's frames come first; never mind if not */ }
    av_log_set_level(AV_LOG_QUIET);
    avformat_network_init();
    if (argc >= 2 && !strcmp(argv[1], "sync")) return sync_list(argc, argv);
    if (argc >= 2 && !strcmp(argv[1], "logos")) return logos(argc, argv);
    if (argc >= 2 && !strcmp(argv[1], "get")) return get(argc, argv);
    fprintf(stderr, "tvnet sync CONF NAME LISTDIR EPGDIR | tvnet logos LISTFILE OUTDIR W H | tvnet get URL OUT\n");
    return 2;
}
