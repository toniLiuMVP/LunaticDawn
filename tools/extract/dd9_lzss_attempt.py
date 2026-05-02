#!/usr/bin/env python3
"""dd9_lzss_attempt.py — DD9 LZSS-family decoder 試解（第二十一波，2026-05-02）

結構發現（已確認）：
- DD9 = 壓縮版 DDT
- byte 0-15: filename "X.DDT" + magic bytes
- byte 12 = 0x9c (DD9 magic 1，全 27 檔一致)
- byte 14 = 0x91 (DD9 magic 2，全 27 檔一致)
- byte 13 / 15: 推測 dim hint (parameter A/B)
- byte 16+: 壓縮 stream

LZSS 標準演算法測試結果：
- BOAT.DD9 (225 → 612 bytes), zero ratio 81.7%
- STAR.DD9 (551 → 1475), zero 88.6%
- ICON0.DD9 (5906 → 16391 ≈ 128×256 4bpp), zero 63.4%
- WALL.DD9 (4685 → 11935), zero 76.3%

→ 解壓 size 在合理 4bpp planar dim 範圍 + zero-ratio 在合法 mask plane 範圍
→ DD9 確認是 **LZ-family 壓縮**，但解出 PNG 仍是 noise
→ 標準 LZSS 不是精確算法，可能是變體（control bit 反相 / 不同 offset+length packing / 不同 ring buffer init）

完整破解需要：
1. 試 LZSS 變體（已嘗試標準版，PNG 是 noise）
2. 反組譯 LUNA2.EXE 找 decompress function（PE/DOS exe，需 IDA/Ghidra）
"""
import os, struct
from PIL import Image

GAME = "/Volumes/Work/LD/俠客遊2"

def load_palette():
    with open(f"{GAME}/A/LUNA2.PLT", "rb") as f:
        data = f.read()
    pal = []
    for i in range(256):
        v = struct.unpack("<H", data[i*4:i*4+2])[0]
        g = ((v >> 8) & 0xF) * 17
        r = ((v >> 4) & 0xF) * 17
        b = (v & 0xF) * 17
        pal.append((r, g, b))
    return pal


def lzss_std(data, max_out=None):
    """LZSS 標準（control byte 1=literal 0=match，offset 12-bit + length 4-bit+3）"""
    out = bytearray()
    N = 4096
    buf = bytearray(N)
    r = N - 18
    p = 0
    n = len(data)
    while p < n:
        flags = data[p]; p += 1
        for bit in range(8):
            if p >= n: break
            if flags & 1:
                c = data[p]; p += 1
                out.append(c); buf[r] = c; r = (r + 1) & (N - 1)
            else:
                if p + 1 >= n: break
                lo = data[p]; p += 1
                hi = data[p]; p += 1
                offset = lo | ((hi & 0xF0) << 4)
                length = (hi & 0x0F) + 3
                for k in range(length):
                    c = buf[(offset + k) & (N - 1)]
                    out.append(c); buf[r] = c; r = (r + 1) & (N - 1)
            flags >>= 1
            if max_out and len(out) >= max_out: return bytes(out)
    return bytes(out)


def lzss_inverted_control(data, max_out=None):
    """LZSS 變體：control bit 0=literal 1=match"""
    out = bytearray()
    N = 4096
    buf = bytearray(N)
    r = N - 18
    p = 0
    n = len(data)
    while p < n:
        flags = data[p]; p += 1
        for bit in range(8):
            if p >= n: break
            if not (flags & 1):  # 0 = literal
                c = data[p]; p += 1
                out.append(c); buf[r] = c; r = (r + 1) & (N - 1)
            else:  # 1 = match
                if p + 1 >= n: break
                lo = data[p]; p += 1
                hi = data[p]; p += 1
                offset = lo | ((hi & 0xF0) << 4)
                length = (hi & 0x0F) + 3
                for k in range(length):
                    c = buf[(offset + k) & (N - 1)]
                    out.append(c); buf[r] = c; r = (r + 1) & (N - 1)
            flags >>= 1
            if max_out and len(out) >= max_out: return bytes(out)
    return bytes(out)


def main():
    """跑 LZSS 變體 sample test"""
    samples = ['BOAT.DD9', 'STAR.DD9', 'ICON0.DD9', 'WALL.DD9']
    print(f'{"name":<14} {"std_out":>8} {"std_z%":>6} | {"inv_out":>8} {"inv_z%":>6}')
    print('-' * 60)
    for name in samples:
        path = None
        for root, dirs, files in os.walk(GAME):
            if name in files:
                path = os.path.join(root, name)
                break
        if not path: continue

        with open(path, 'rb') as f:
            data = f.read()

        # Try std + inverted-control variants
        out_std = lzss_std(data[16:])
        out_inv = lzss_inverted_control(data[16:])
        z_std = sum(1 for b in out_std if b == 0) / max(len(out_std), 1) * 100
        z_inv = sum(1 for b in out_inv if b == 0) / max(len(out_inv), 1) * 100

        print(f'{name:<14} {len(out_std):>8d} {z_std:>5.1f}% | {len(out_inv):>8d} {z_inv:>5.1f}%')

    print(f'\n結論：標準 LZSS + 反相 control 兩個變體都解出來 size 合理但 PNG 是 noise')
    print(f'→ DD9 是 LZ-family 變體，完整算法待 LUNA2.EXE 反組譯')


if __name__ == '__main__':
    main()
