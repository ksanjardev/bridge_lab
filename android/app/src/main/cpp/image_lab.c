/* filter_rgba: one entry point for several filters, selected by `filter`.
 * Pixelate averages each block x block square; grayscale and sepia are per-pixel
 * colour maths in integers (no floats, so it's fast and the same on every ABI). */

#include "image_lab.h"
#include <stdlib.h>

const char* image_lab_version(void) { return "image_lab 1.0 (C, -O3)"; }


/* Separable box blur: horizontal pass into a temp buffer, then vertical pass.
 * Deliberately the same simple algorithm as boxBlurDart() in Dart, so the
 * benchmark measures the runtime (C vs Dart), not a smarter algorithm. */
int32_t box_blur_rgba(const uint8_t* src, uint8_t* dst,
        int32_t w, int32_t h, int32_t r) {
    if (!src || !dst || w < 1 || h < 1 || r < 1) return -1;
    uint8_t* tmp = (uint8_t*)malloc((size_t)w * (size_t)h * 4);
    if (!tmp) return -2;

    /* horizontal pass: src -> tmp */
    for (int32_t y = 0; y < h; y++) {
        const uint8_t* row = src + (int64_t)y * w * 4;
        for (int32_t x = 0; x < w; x++) {
            int32_t x0 = x - r < 0 ? 0 : x - r;
            int32_t x1 = x + r >= w ? w - 1 : x + r;
            int32_t count = x1 - x0 + 1;
            uint32_t sr = 0, sg = 0, sb = 0;
            for (int32_t k = x0; k <= x1; k++) {
                const uint8_t* q = row + (int64_t)k * 4;
                sr += q[0]; sg += q[1]; sb += q[2];
            }
            uint8_t* o = tmp + ((int64_t)y * w + x) * 4;
            o[0] = (uint8_t)(sr / count);
            o[1] = (uint8_t)(sg / count);
            o[2] = (uint8_t)(sb / count);
            o[3] = 255;
        }
    }

    /* vertical pass: tmp -> dst */
    for (int32_t y = 0; y < h; y++) {
        int32_t y0 = y - r < 0 ? 0 : y - r;
        int32_t y1 = y + r >= h ? h - 1 : y + r;
        int32_t count = y1 - y0 + 1;
        for (int32_t x = 0; x < w; x++) {
            uint32_t sr = 0, sg = 0, sb = 0;
            for (int32_t k = y0; k <= y1; k++) {
                const uint8_t* q = tmp + ((int64_t)k * w + x) * 4;
                sr += q[0]; sg += q[1]; sb += q[2];
            }
            uint8_t* o = dst + ((int64_t)y * w + x) * 4;
            o[0] = (uint8_t)(sr / count);
            o[1] = (uint8_t)(sg / count);
            o[2] = (uint8_t)(sb / count);
            o[3] = 255;
        }
    }

    free(tmp);
    return 0;
}

/* Separable box blur: blur rows, then columns. O(pixels) per pass instead of
 * O(pixels x radius^2) for the naive 2D version. */
int32_t filter_rgba(const uint8_t* src, uint8_t* dst,
        int32_t w, int32_t h, int32_t filter, int32_t amount) {
    if (!src || !dst || w < 1 || h < 1) return -1;
    int64_t n = (int64_t)w * h;

    switch (filter) {
        case 0: /* blur */
            return box_blur_rgba(src, dst, w, h, amount < 1 ? 1 : amount);

        case 1: { /* pixelate: replace every block x block square by its average colour */
            int32_t blk = amount < 2 ? 2 : amount;
            for (int32_t by = 0; by < h; by += blk) {
                int32_t ey = by + blk > h ? h : by + blk;
                for (int32_t bx = 0; bx < w; bx += blk) {
                    int32_t ex = bx + blk > w ? w : bx + blk;
                    uint32_t sr = 0, sg = 0, sb = 0;
                    uint32_t count = (uint32_t)(ex - bx) * (uint32_t)(ey - by);
                    for (int32_t y = by; y < ey; y++) {
                        for (int32_t x = bx; x < ex; x++) {
                            const uint8_t* q = src + ((int64_t)y * w + x) * 4;
                            sr += q[0]; sg += q[1]; sb += q[2];
                        }
                    }
                    uint8_t ar = (uint8_t)(sr / count);
                    uint8_t ag = (uint8_t)(sg / count);
                    uint8_t ab = (uint8_t)(sb / count);
                    for (int32_t y = by; y < ey; y++) {
                        for (int32_t x = bx; x < ex; x++) {
                            uint8_t* o = dst + ((int64_t)y * w + x) * 4;
                            o[0] = ar; o[1] = ag; o[2] = ab; o[3] = 255;
                        }
                    }
                }
            }
            return 0;
        }

        case 2: /* grayscale */
            for (int64_t i = 0; i < n; i++) {
                const uint8_t* q = src + i * 4;
                uint8_t* o = dst + i * 4;
                uint8_t l = (uint8_t)((q[0] * 77 + q[1] * 150 + q[2] * 29) >> 8);
                o[0] = o[1] = o[2] = l;
                o[3] = 255;
            }
            return 0;

        case 3: /* sepia */
            for (int64_t i = 0; i < n; i++) {
                const uint8_t* q = src + i * 4;
                uint8_t* o = dst + i * 4;
                uint32_t r = q[0], g = q[1], bl = q[2];
                uint32_t tr = (r * 393 + g * 769 + bl * 189) / 1000;
                uint32_t tg = (r * 349 + g * 686 + bl * 168) / 1000;
                uint32_t tb = (r * 272 + g * 534 + bl * 131) / 1000;
                o[0] = (uint8_t)(tr > 255 ? 255 : tr);
                o[1] = (uint8_t)(tg > 255 ? 255 : tg);
                o[2] = (uint8_t)(tb > 255 ? 255 : tb);
                o[3] = 255;
            }
            return 0;

        default:
            return -3;
    }
}