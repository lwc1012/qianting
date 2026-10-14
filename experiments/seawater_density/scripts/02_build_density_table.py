# -*- coding: utf-8 -*-
"""
步骤 2：把 WOA23 网格温盐数据加工成项目可用的"海水密度表"，并完成质量控制。

流程：
  1) 从下载的 WOA23 CSV 中，按 (海区, 月份, 深度) 抽取出温度 T 与盐度 S 的气候态平均
     及其标准差 sd、观测样本数 dd；
  2) 用 EOS-80（UNESCO 1983）状态方程计算现场密度 rho = f(S, T, p)，
     其中 p 由 depth 与纬度经 seawater.pres 换算；
  3) 不确定度传播：u(rho) = sqrt( (dRho/dT * u_T)^2 + (dRho/dS * u_S)^2 )，
     偏导数用中心差分求取；同时给出 sd/sqrt(N) 的标准误版本；
  4) 质量控制：缺测检查、物理量程检查、层化稳定性检查、样本量检查、
     季节性合理性检查、空间合理性检查、EOS-80 标准值校验；
  5) 输出结构化数据集、查找表(JSON)、质量控制报告。

注意：WOA23 的 CSV 产品会**省略行尾的缺测值**，因此每行字段数不等，
      必须按深度下标解析而不能按固定列数解析。

用法：python 02_build_density_table.py
"""
import argparse
import gzip
import json
import math
import os
import sys

import numpy as np
import seawater as sw

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# ---------------------------------------------------------------- 配置

# 目标海区（经纬度均落在 WOA23 1° 网格中心上）
AREAS = [
    ("渤海中部", 38.5, 119.5),
    ("黄海中部", 35.5, 123.5),
    ("东海陆架", 28.5, 125.5),
    ("南海北部", 18.5, 114.5),
]
MONTHS = [("01", "1月"), ("04", "4月"), ("07", "7月"), ("10", "10月")]
# WOA23 标准层中 0~300 m 的全部层次
DEPTHS = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80,
          85, 90, 95, 100, 125, 150, 175, 200, 225, 250, 275, 300]
# 报告与后续分析关心的关键深度
KEY_DEPTHS = [0, 10, 50, 100, 200, 300]

RHO_CODE = 1.020                        # Main.qml 中的硬编码值，单位 g/cm3
TOL_INVERSION = 0.01                    # 层化倒置容差 kg/m3

RANGE_T = (-3.0, 40.0)
RANGE_S = (0.0, 42.0)
RANGE_RHO = (1000.0, 1045.0)

HERE = os.path.dirname(os.path.abspath(__file__))
# 原始下载留在 data/raw（体积大，不属于交付物）；结构化产出写入交付子文件夹
RAW = os.path.abspath(os.path.join(HERE, "..", "data", "raw"))
OUT = os.path.abspath(os.path.join(
    HERE, "..", "面向多型潜航器的多模态空间感知与潜浮均衡协同决策系统", "data"))


def log(msg):
    print(msg, flush=True)


def fname(rawdir, letter, month, stat):
    return os.path.join(rawdir, f"woa23_decav91C0_{letter}{month}{stat}01.csv.gz")


# ---------------------------------------------------------------- 读取 WOA23

_depth_cache = {}


def header_depths(path):
    """从文件头的注释行解析标准层深度列表。"""
    if path in _depth_cache:
        return _depth_cache[path]
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            if "(M):" in line:
                raw = line.split("(M):", 1)[1].strip()
                dep = [float(x) for x in raw.split(",")]
                _depth_cache[path] = dep
                return dep
            if not line.startswith("#"):
                break
    raise RuntimeError(f"{path} 未找到深度表头")


def extract_point(path, lat, lon, depths):
    """抽取单个 (lat, lon) 网格点上各标准层的值；行尾省略的层记为缺测(nan)。"""
    out = {d: math.nan for d in depths}
    if not os.path.exists(path):
        return out, False
    dep = header_depths(path)
    pos = {d: i for i, d in enumerate(dep)}
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("#"):
                continue
            parts = line.rstrip("\r\n").split(",")
            if len(parts) < 2:
                continue
            try:
                la, lo = float(parts[0]), float(parts[1])
            except ValueError:
                continue
            if abs(la - lat) > 1e-6 or abs(lo - lon) > 1e-6:
                continue
            vals = parts[2:]
            for d in depths:
                j = pos.get(float(d))
                if j is None or j >= len(vals):
                    continue                      # 行尾省略 -> 缺测
                v = vals[j].strip()
                if v in ("", "nan", "NaN"):
                    continue
                try:
                    out[d] = float(v)
                except ValueError:
                    pass
            return out, True
    return out, False


# ---------------------------------------------------------------- 物理计算

def t90_to_t68(t90):
    """ITS-90 -> IPTS-68 温标换算（EOS-80 要求 IPTS-68）。"""
    try:
        return float(sw.t90ton68(np.asarray([t90], dtype=float))[0])
    except Exception:                                   # noqa: BLE001
        return t90 * 1.00024


def density(S, T68, depth, lat):
    """EOS-80 现场密度，kg/m3。"""
    p = float(sw.pres(np.asarray([depth], dtype=float),
                      np.asarray([lat], dtype=float))[0])
    return float(sw.dens(S, T68, p)), p


def partials(S, T68, p, h=0.01):
    """密度对温度、盐度的中心差分偏导数。"""
    drho_dT = (sw.dens(S, T68 + h, p) - sw.dens(S, T68 - h, p)) / (2 * h)
    drho_dS = (sw.dens(S + h, T68, p) - sw.dens(S - h, T68, p)) / (2 * h)
    return float(drho_dT), float(drho_dS)


def check_eos80():
    """EOS-80 标准校验值：S=35, T=15C(IPTS-68), p=0 -> 1025.973 kg/m3。"""
    rho = float(sw.dens(35.0, 15.0, 0.0))
    return rho, abs(rho - 1025.973) < 0.01


# ---------------------------------------------------------------- 主流程

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=RAW)
    ap.add_argument("--out", default=OUT)
    args = ap.parse_args()
    rawdir = os.path.abspath(args.raw)
    outdir = os.path.abspath(args.out)
    os.makedirs(outdir, exist_ok=True)

    rho_chk, ok_chk = check_eos80()
    log(f"EOS-80 自检: dens(35,15,0) = {rho_chk:.4f} kg/m3  "
        f"({'通过' if ok_chk else '不通过'})")

    records = []
    total = len(AREAS) * len(MONTHS)
    n = 0
    for area, lat, lon in AREAS:
        for mm, mlabel in MONTHS:
            n += 1
            log(f"[{n}/{total}] {area} {mlabel}")
            fields = {}
            for letter, key in (("t", "T"), ("s", "S")):
                for stat in ("an", "sd", "dd"):
                    vals, _ = extract_point(fname(rawdir, letter, mm, stat),
                                            lat, lon, DEPTHS)
                    fields[f"{key}_{stat}"] = vals

            for d in DEPTHS:
                T = fields["T_an"][d]
                S = fields["S_an"][d]
                sT = fields["T_sd"][d]
                sS = fields["S_sd"][d]
                N = fields["S_dd"][d]

                rec = {
                    "海区": area, "纬度": lat, "经度": lon,
                    "月份": mlabel, "深度_m": d,
                    "温度_C": T, "温度标准差_C": sT,
                    "盐度_PSU": S, "盐度标准差_PSU": sS, "数据分布_dd": N,
                }
                if any(math.isnan(v) for v in (T, S)):
                    rec.update({"压力_dbar": math.nan, "密度_kgm3": math.nan,
                                "密度_gcm3": math.nan,
                                "密度不确定度_kgm3": math.nan,
                                "密度标准误_kgm3": math.nan,
                                "与1.020差值_kgm3": math.nan,
                                "dRho_dT": math.nan, "dRho_dS": math.nan})
                    records.append(rec)
                    continue

                T68 = t90_to_t68(T)
                rho, p = density(S, T68, d, lat)
                drho_dT, drho_dS = partials(S, T68, p)

                uT = 0.0 if math.isnan(sT) else sT
                uS = 0.0 if math.isnan(sS) else sS
                u_rho = math.hypot(drho_dT * uT, drho_dS * uS)
                if N and not math.isnan(N) and N > 1:
                    u_se = u_rho / math.sqrt(N)
                else:
                    u_se = math.nan

                rec.update({
                    "压力_dbar": p,
                    "密度_kgm3": rho,
                    "密度_gcm3": rho / 1000.0,
                    "密度不确定度_kgm3": u_rho,
                    "密度标准误_kgm3": u_se,
                    "与1.020差值_kgm3": rho - RHO_CODE * 1000.0,
                    "dRho_dT": drho_dT, "dRho_dS": drho_dS,
                })
                records.append(rec)

    import pandas as pd
    df = pd.DataFrame(records)
    cols = ["海区", "纬度", "经度", "月份", "深度_m", "温度_C", "温度标准差_C",
            "盐度_PSU", "盐度标准差_PSU", "数据分布_dd", "压力_dbar",
            "密度_kgm3", "密度_gcm3", "密度不确定度_kgm3", "密度标准误_kgm3",
            "与1.020差值_kgm3", "dRho_dT", "dRho_dS"]
    df = df[cols]

    # ------------------------------------------------------------ 质量控制
    issues = []
    df["QC_缺测"] = df["密度_kgm3"].isna()
    for _, r in df[df["QC_缺测"]].iterrows():
        issues.append(("缺测", f"{r['海区']} {r['月份']} {r['深度_m']:.0f} m "
                              f"温盐缺测（该处水深不足或无观测）"))

    df["QC_量程"] = True
    for _, r in df[~df["QC_缺测"]].iterrows():
        bad = []
        if not (RANGE_T[0] <= r["温度_C"] <= RANGE_T[1]):
            bad.append(f"温度 {r['温度_C']:.2f}C")
        if not (RANGE_S[0] <= r["盐度_PSU"] <= RANGE_S[1]):
            bad.append(f"盐度 {r['盐度_PSU']:.2f}")
        if not (RANGE_RHO[0] <= r["密度_kgm3"] <= RANGE_RHO[1]):
            bad.append(f"密度 {r['密度_kgm3']:.2f}")
        if bad:
            df.loc[r.name, "QC_量程"] = False
            issues.append(("量程", f"{r['海区']} {r['月份']} {r['深度_m']:.0f} m 越界: "
                                  + "; ".join(bad)))

    df["QC_层化"] = True
    for (area, mm), g in df[~df["QC_缺测"]].groupby(["海区", "月份"], sort=False):
        g = g.sort_values("深度_m")
        prev_d = prev_rho = None
        for _, r in g.iterrows():
            if prev_rho is not None:
                d_rho = r["密度_kgm3"] - prev_rho
                if d_rho < -TOL_INVERSION:
                    df.loc[r.name, "QC_层化"] = False
                    issues.append(("层化", f"{area} {mm} {prev_d:.0f}->"
                                          f"{r['深度_m']:.0f} m 密度减小 "
                                          f"{-d_rho:.3f} kg/m3（密度倒置）"))
            prev_d, prev_rho = r["深度_m"], r["密度_kgm3"]

    # 覆盖度：WOA23 的 dd（Data distribution）字段。它反映该格点气候态的观测支撑，
    # 缺失或过小只记为警告，不否决记录本身（否则近海海区会被整片丢掉，失去分析价值）。
    df["QC_覆盖警告"] = ""
    for _, r in df[~df["QC_缺测"]].iterrows():
        N = r["数据分布_dd"]
        if math.isnan(N):
            df.loc[r.name, "QC_覆盖警告"] = "dd 无记录"
        elif N < 10:
            df.loc[r.name, "QC_覆盖警告"] = f"dd={N:.0f}"
    n_warn = int((df["QC_覆盖警告"] != "").sum())
    if n_warn:
        issues.append(("覆盖度警告",
                       f"{n_warn} 条记录 dd 缺失或 <10（不否决，仅提示观测支撑薄弱）"))

    df["QC_通过"] = (~df["QC_缺测"]) & df["QC_量程"] & df["QC_层化"]

    good = df[df["QC_通过"]]

    # ---- 合理性检查（物理/地理常识） ----------------------------------
    plaus = []
    findings = []

    # (a) 季节性：北半球这些海区表层密度应冬高夏低。只查 1月>7月，
    #     因为秋季(10月)表层受夏季增温与长江冲淡水影响可以比春季(4月)更轻，
    #     这是真实特征而非数据错误。
    surf = df[(df["深度_m"] == 0) & df["QC_通过"]]
    for area, _, _ in AREAS:
        s = surf[surf["海区"] == area].set_index("月份")["密度_kgm3"]
        if {"1月", "7月"} <= set(s.index) and s["1月"] <= s["7月"]:
            plaus.append(("季节性异常",
                          f"{area} 表层 1月密度 {s['1月']:.2f} 不高于 "
                          f"7月 {s['7月']:.2f} kg/m³"))

    # (b) 空间梯度：必须用**盐度**判断。密度的空间排序被温度主导
    #     （冬季渤海 4 °C 的水比南海 24 °C 的水重），不能作为检查判据。
    #     可靠的判据是中国近海的盐度梯度：渤海受河流淡水影响最强 -> 最淡。
    for d in (0, 10):
        for mm, mlabel in MONTHS:
            s = df[(df["深度_m"] == d) & (df["月份"] == mlabel) & df["QC_通过"]]
            if s["海区"].nunique() < 4:
                continue
            smin = s.loc[s["盐度_PSU"].idxmin(), "海区"]
            smax = s.loc[s["盐度_PSU"].idxmax(), "海区"]
            if smin != "渤海中部":
                plaus.append(("盐度梯度异常",
                              f"{d} m {mlabel} 最低盐度出现在 {smin}（预期渤海中部）"))
            if smax == "渤海中部":
                plaus.append(("盐度梯度异常",
                              f"{d} m {mlabel} 最高盐度出现在 渤海中部（预期外海）"))

    # ---- 客观记录（非异常，供报告引用） --------------------------------
    for d in (0, 10, 50, 100, 300):
        s = good[good["深度_m"] == d]
        if not len(s):
            continue
        lo = s.loc[s["密度_kgm3"].idxmin()]
        hi = s.loc[s["密度_kgm3"].idxmax()]
        findings.append(
            f"{d:>3.0f} m：最轻 **{lo['密度_kgm3']:.2f}** kg/m³"
            f"（{lo['海区']} {lo['月份']}）／"
            f"最重 **{hi['密度_kgm3']:.2f}** kg/m³（{hi['海区']} {hi['月份']}）")

    # ------------------------------------------------------------ 输出
    csv_path = os.path.join(outdir, "seawater_density.csv")
    df.to_csv(csv_path, index=False, encoding="utf-8-sig", float_format="%.6f")

    env = good.groupby("深度_m")["密度_kgm3"].agg(
        ["min", "max", "mean", "std", "count"]).reset_index()
    env.columns = ["深度_m", "最小密度_kgm3", "最大密度_kgm3", "平均密度_kgm3",
                   "标准差_kgm3", "样本数"]
    env["最小密度_gcm3"] = env["最小密度_kgm3"] / 1000.0
    env["最大密度_gcm3"] = env["最大密度_kgm3"] / 1000.0
    env.to_csv(os.path.join(outdir, "density_envelope.csv"),
               index=False, encoding="utf-8-sig", float_format="%.6f")

    lookup = {"meta": {
        "source": "NOAA WOA23 decav91C0 1-degree climatology (1991-2020)",
        "eos": "EOS-80 / UNESCO 1983",
        "unit": "kg/m3",
        "structure": "海区 -> 月份 -> 深度(m) -> {rho, u, T, S}",
    }, "table": {}}
    for area, _, _ in AREAS:
        lookup["table"][area] = {}
        for mm, mlabel in MONTHS:
            sub = good[(good["海区"] == area) & (good["月份"] == mlabel)]
            lookup["table"][area][mlabel] = {
                str(int(r["深度_m"])): {
                    "rho": round(r["密度_kgm3"], 3),
                    "u": round(r["密度不确定度_kgm3"], 4),
                    "T": round(r["温度_C"], 3),
                    "S": round(r["盐度_PSU"], 3),
                } for _, r in sub.iterrows()}
    with open(os.path.join(outdir, "density_lookup.json"), "w",
              encoding="utf-8") as f:
        json.dump(lookup, f, ensure_ascii=False, indent=2)

    write_qc_report(os.path.join(outdir, "qc_report.md"),
                    df, env, issues, plaus, findings, rho_chk, ok_chk)

    # 每种 (海区, 月) 组合实际上能取到的最大深度
    log("\n各海区各月可用最大深度：")
    for area, _, _ in AREAS:
        row = []
        for mm, mlabel in MONTHS:
            sub = good[(good["海区"] == area) & (good["月份"] == mlabel)]
            row.append(f"{mlabel}:{sub['深度_m'].max():.0f}m" if len(sub) else f"{mlabel}:-")
        log(f"  {area}: " + "  ".join(row))

    log(f"\n完成：{len(df)} 条记录，QC 通过 {int(df['QC_通过'].sum())} 条，"
        f"缺测 {int(df['QC_缺测'].sum())} 条，其他问题 {len(issues)} 项，"
        f"合理性提示 {len(plaus)} 项")
    log(f"输出目录：{outdir}")
    return 0


def write_qc_report(path, df, env, issues, plaus, findings, rho_chk, ok_chk):
    import pandas as pd  # noqa: F401
    good = df[df["QC_通过"]]
    lines = []
    A = lines.append

    A("# 海水密度数据质量控制报告\n")
    A("## 1 数据来源与处理方法\n")
    A("| 项目 | 内容 |")
    A("| --- | --- |")
    A("| 原始数据 | NOAA WOA23（World Ocean Atlas 2023）1°×1° 网格气候态 |")
    A("| 统计期 | 1991–2020 年（decav91C0） |")
    A("| 变量 | 温度 t、盐度 s 的气候态平均 an、标准差 sd、观测样本数 dd |")
    A("| 时间取样 | 1/4/7/10 月，代表冬/春/夏/秋 |")
    A("| 空间取样 | 渤海中部(38.5N,119.5E)、黄海中部(35.5N,123.5E)、"
      "东海陆架(28.5N,125.5E)、南海北部(18.5N,114.5E) |")
    A("| 深度取样 | WOA23 标准层 0–300 m 共 29 层 |")
    A("| 密度算法 | EOS-80（UNESCO 1983），ρ=ρ(S,T,p)，p 由 press(depth,lat) 换算 |")
    A("| 温标处理 | WOA23 为 ITS-90，按 T68=1.00024·T90 换算为 EOS-80 要求的 IPTS-68 |")
    A("")

    A("## 2 算法校验\n")
    A("EOS-80 标准校验值 ρ(35, 15 °C, 0 dbar) = 1025.973 kg/m³\n")
    A(f"- 本实现结果：**{rho_chk:.4f} kg/m³**")
    A(f"- 偏差 {abs(rho_chk - 1025.973):.4f} kg/m³ → **"
      f"{'通过' if ok_chk else '不通过'}**（判据 < 0.01）\n")

    A("## 3 数据完整性\n")
    A(f"- 计划记录数 {len(AREAS) * len(MONTHS) * len(DEPTHS)}"
      f"（4 海区 × 4 月 × 29 层）")
    A(f"- 实际生成 {len(df)}")
    A(f"- 缺测 {int(df['QC_缺测'].sum())}，QC 全部通过 {int(df['QC_通过'].sum())}\n")

    A("### 3.1 各海区实际可用深度与观测支撑\n")
    A("WOA23 的 CSV 产品会省略行尾缺测值。实测结果表明各海区可用深度受**实际水深**限制，"
      "同时 `dd`（Data distribution）字段反映该格点的观测支撑强度：\n")
    A("| 海区 | 最大可用深度(m) | dd 取值 | 说明 |")
    A("| --- | --- | --- | --- |")
    note = {"渤海中部": "平均水深仅约 18 m，25 m 以下无数据；且 dd 在文件中**整行缺失**",
            "黄海中部": "水深约 50–80 m，65 m 以下无数据",
            "东海陆架": "陆架水深约 100 m，150 m 以下无数据",
            "南海北部": "陆坡深水区，0–300 m 全覆盖"}
    for area, _, _ in AREAS:
        sub = good[good["海区"] == area]
        mx = sub["深度_m"].max() if len(sub) else float("nan")
        n_sub = sub["数据分布_dd"].dropna()
        dd_txt = "无记录" if not len(n_sub) else (
            f"{n_sub.min():.0f}" if n_sub.min() == n_sub.max()
            else f"{n_sub.min():.0f}–{n_sub.max():.0f}")
        A(f"| {area} | {mx:.0f} | {dd_txt} | {note.get(area,'')} |")
    A("")
    A("**这一条本身就是本次实验的结论之一**：要求解算器在 300 m 深度用上真实密度，"
      "渤海/黄海/东海三个近海海区根本提供不了对应观测，只有南海北部具备完整剖面。\n")
    dd_bits = []
    for area, _, _ in AREAS:
        n_sub = good[good["海区"] == area]["数据分布_dd"].dropna()
        if not len(n_sub):
            dd_bits.append(f"{area} 无记录")
        else:
            dd_bits.append(f"{area} dd∈[{n_sub.min():.0f}, {n_sub.max():.0f}]")
    A("更进一步，即便在能取到数值的格点上，观测支撑也很薄：" + "，".join(dd_bits)
      + "。而 WOA23 全网格该字段的取值范围可达 **728**"
      "（本实验实测，见 `data/raw/woa23_decav91C0_t01dd01.csv.gz`）。"
      "也就是说中国近海这几个格点的气候态是由个位数到二十几次记录撑起来的，"
      "渤海格点在 dd 产品中甚至没有记录。**这直接限制了密度参数化的可信度上限。**\n")

    A("## 4 质量问题清单\n")
    if not issues:
        A("无。\n")
    else:
        by_kind = {}
        for kind, msg in issues:
            by_kind.setdefault(kind, []).append(msg)
        A("| 类型 | 项数 | 是否否决记录 |")
        A("| --- | --- | --- |")
        veto = {"缺测": "是（该层无数据）", "量程": "是", "层化": "是",
                "覆盖度警告": "否，仅提示"}
        for kind, msgs in by_kind.items():
            A(f"| {kind} | {len(msgs)} | {veto.get(kind,'是')} |")
        A("")
        A("判据说明：\n")
        A("- **缺测**：该深度无温盐值。原因绝大多数是水深不足（渤海 25 m 以深、"
          "黄海 65 m 以深、东海 150 m 以深本就无水体），属合理缺测而非数据错误。")
        A("- **量程**：T∈[-3,40] °C、S∈[0,42]、ρ∈[1000,1045] kg/m³。")
        A("- **层化**：同一海区同一月份，密度随深度不得减小超过 0.01 kg/m³（稳定性）。")
        A("- **覆盖度警告**：dd 缺失或 <10，提示观测支撑薄弱，不否决。\n")
        for kind, msgs in by_kind.items():
            if kind in ("缺测", "覆盖度警告"):
                A(f"**{kind}**：共 {len(msgs)} 项"
                  + ("，明细从略（见结构化数据集逐行标记）。\n" if kind == "缺测" else "。\n"))
                continue
            A(f"**{kind}**\n")
            for m in msgs:
                A(f"- {m}")
            A("")

    A("## 5 密度分布（仅 QC 通过的记录）\n")
    A("| 深度(m) | 最小(kg/m³) | 最大(kg/m³) | 平均(kg/m³) | 样本数 |")
    A("| --- | --- | --- | --- | --- |")
    for _, r in env.iterrows():
        if float(r["深度_m"]) not in KEY_DEPTHS and r["深度_m"] % 25:
            continue
        A(f"| {r['深度_m']:.0f} | {r['最小密度_kgm3']:.3f} | {r['最大密度_kgm3']:.3f} "
          f"| {r['平均密度_kgm3']:.3f} | {int(r['样本数'])} |")
    A("")

    if len(good):
        lo, hi = good["密度_kgm3"].min(), good["密度_kgm3"].max()
        A("## 6 与程序硬编码值的对照\n")
        A("Main.qml 中 `waterDensity` 取 1.020 g/cm³ = 1020 kg/m³，全程序单一常数。\n")
        A(f"- 实测范围 **{lo:.2f} – {hi:.2f} kg/m³**"
          f"（{lo/1000:.4f} – {hi/1000:.4f} g/cm³）")
        A(f"- 与 1020 kg/m³ 的最大偏差 **{max(abs(lo-1020), abs(hi-1020)):.2f} kg/m³**，"
          f"相当于硬编码值的 {max(abs(lo-1020), abs(hi-1020))/1020*100:.2f}%")
        A(f"- {len(good)} 条记录相对 1020 kg/m³ 的平均偏差 "
          f"**{good['与1.020差值_kgm3'].mean():+.2f} kg/m³**")
        n_below = int((good["密度_kgm3"] < 1020).sum())
        A(f"- 低于 1020 kg/m³ 的记录 **{n_below} / {len(good)}**"
          + ("；也就是说 1.020 实际上是全部实测样本的**下界附近**，"
             "程序取的是一个偏轻的值。\n" if n_below == 0 else "。\n"))
        if findings:
            A("各深度上取到的最轻/最重水样：\n")
            for line in findings:
                A(f"- {line}")
            A("")

        A("## 7 不确定度传播\n")
        A("按 u(ρ)=√[(∂ρ/∂T·u_T)² + (∂ρ/∂S·u_S)²] 传播，偏导数用中心差分（步长 0.01）。"
          "u_T、u_S 取 WOA23 的 sd 字段。\n")
        A(f"- sd 版不确定度：中位数 **{good['密度不确定度_kgm3'].median():.4f} kg/m³**，"
          f"最大 {good['密度不确定度_kgm3'].max():.4f} kg/m³")
        se = good["密度标准误_kgm3"].dropna()
        if len(se):
            A(f"- 若把 dd 视作观测次数，按 sd/√dd 折算的标准误中位数 "
              f"**{se.median():.4f} kg/m³**，最大 {se.max():.4f} kg/m³"
              f"（该折算依赖 dd 的语义，仅作参考）")
        A("")
        A("sd 反映的是网格内**变率**（年际＋空间），把它当作不确定度是保守上界。"
          "两者都远小于密度取值本身的跨度，"
          "因此后续敏感性分析以**密度取值跨度**而非**统计不确定度**作为自变量。\n")
        A("> 说明：WOA23 对 `dd` 字段的官方定义为 \"Data distribution\"，"
          "本实验**未假定**它就是观测次数，只把它当作观测支撑强弱的相对指标使用。\n")

    A("## 8 合理性检查\n")
    A("判据：\n")
    A("- 季节性：北半球表层密度应冬高夏低（只查 1月 > 7月；"
      "10月与4月不做判据，因为秋季表层受夏季增温与长江冲淡水影响"
      "可以比春季更轻，这是真实特征）。")
    A("- 空间梯度：用**盐度**而不用密度判断。中国近海盐度受河流淡水影响，"
      "应为 渤海 < 黄海 < 外海。密度的空间排序被温度主导"
      "（冬季渤海约 4 °C 的水比南海约 24 °C 的水重），不能作为判据。\n")
    if not plaus:
        A("全部通过。\n")
    else:
        A("| 类型 | 说明 |")
        A("| --- | --- |")
        for kind, msg in plaus:
            A(f"| {kind} | {msg} |")
        A("")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    sys.exit(main())
