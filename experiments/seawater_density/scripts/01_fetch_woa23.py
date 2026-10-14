# -*- coding: utf-8 -*-
"""
步骤 1：从 NOAA NCEI 下载 WOA23（World Ocean Atlas 2023）网格化气候态数据。

数据源：World Ocean Atlas 2023, 1° 网格, 1991-2020 气候态平均 (decav91C0)
        产品格式：comma separated values (.csv.gz)
        下载地址：https://www.ncei.noaa.gov/data/oceans/woa/WOA23/DATA/

下载内容：
  temperature / salinity 两个要素
  × 4 个代表月份（1/4/7/10 月）
  × 2 个统计量（an = 气候态平均值, sd = 标准差）

用法：python 01_fetch_woa23.py [--out DIR]
"""
import argparse
import os
import sys
import time

import requests

BASE = "https://www.ncei.noaa.gov/data/oceans/woa/WOA23/DATA"

# (变量目录名, CSV 文件名里的单字母代号)
VARIABLES = [("temperature", "t"), ("salinity", "s")]
MONTHS = ["01", "04", "07", "10"]          # 冬 春 夏 秋
STATS = {"an": "气候态平均", "sd": "标准差", "dd": "观测样本数"}


def remote_url(var_dir, letter, month, stat):
    fname = f"woa23_decav91C0_{letter}{month}{stat}01.csv.gz"
    return f"{BASE}/{var_dir}/csv/decav91C0/1.00/{fname}", fname


def download(url, dest, retries=3):
    """带断点续传与重试的下载。"""
    tmp = dest + ".part"
    for attempt in range(1, retries + 1):
        try:
            got = os.path.getsize(tmp) if os.path.exists(tmp) else 0
            headers = {"Range": f"bytes={got}-"} if got else {}
            with requests.get(url, headers=headers, stream=True, timeout=120) as r:
                if got and r.status_code == 200:
                    got = 0                      # 服务端不支持续传，重头来
                    tmp and os.remove(tmp)
                elif got and r.status_code != 206:
                    raise RuntimeError(f"HTTP {r.status_code}")
                r.raise_for_status()
                mode = "ab" if got and r.status_code == 206 else "wb"
                total = got + int(r.headers.get("Content-Length", 0))
                with open(tmp, mode) as f:
                    done = got
                    for chunk in r.iter_content(chunk_size=1 << 16):
                        f.write(chunk)
                        done += len(chunk)
                        pct = 100.0 * done / total if total else 0
                        sys.stdout.write(f"\r    {pct:5.1f}%  {done/1e6:6.2f}/{total/1e6:.2f} MB")
                        sys.stdout.flush()
            os.replace(tmp, dest)
            print()
            return True
        except Exception as e:                    # noqa: BLE001
            print(f"\n    [第 {attempt}/{retries} 次失败] {e}")
            time.sleep(3 * attempt)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "data", "raw"))
    args = ap.parse_args()
    outdir = os.path.abspath(args.out)
    os.makedirs(outdir, exist_ok=True)

    tasks = []
    for var_dir, letter in VARIABLES:
        for month in MONTHS:
            for stat in STATS:
                tasks.append(remote_url(var_dir, letter, month, stat))

    print(f"共需下载 {len(tasks)} 个文件 -> {outdir}\n")
    ok = fail = 0
    for i, (url, fname) in enumerate(tasks, 1):
        dest = os.path.join(outdir, fname)
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            print(f"[{i}/{len(tasks)}] {fname}  已存在，跳过")
            ok += 1
            continue
        print(f"[{i}/{len(tasks)}] {fname}")
        if download(url, dest):
            ok += 1
        else:
            fail += 1
    print(f"\n完成：成功 {ok}，失败 {fail}")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
