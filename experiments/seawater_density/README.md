# 海水密度获取实验（Week 7）

为 LBSS 均衡算法获取真实海水密度数据的实验。**实验报告见 [`实验报告.md`](实验报告.md)**
（质控细节见 [`data/qc_report.md`](data/qc_report.md)，敏感性结果见 [`data/sensitivity_report.md`](data/sensitivity_report.md)）。

## 结论速览

- 程序硬编码 `waterDensity = 1.020`（`Main.qml:40`），实测真实范围 **1.0203 – 1.0276 kg/L**，硬编码值是全部样本的**下界附近**（0/276 条低于它）。
- 水面模式默认满舱时密度**完全不参与运算**（`missing = 0` 挡掉全部密度项），换密度结果逐位相同。
- 水下救援模式逐条代入 276 条真实密度（414000 次比对），**1.13%** 的决策改变。
- 但排水分支翻转时力矩损失突变 **1687.7 kg·m ≈ 32 块压载铅**；不翻转时最大偏差仅 17.6 kg·m，**小于一块压载铅的台阶**。

## 运行

```bash
cd experiments/seawater_density
python scripts/01_fetch_woa23.py         # 下载 24 个 WOA23 文件（约 55 MB，支持断点续传）
python scripts/02_build_density_table.py # 复算密度 + 不确定度传播 + 质控
python scripts/03_sensitivity_scan.py    # 算法复刻校验 + 4 个敏感性实验
```

脚本按序号执行，输出全部写入 `data/`。`01` 可重复执行（已存在的文件会跳过）。

**依赖**：Python 3.8+，`requests`、`pandas`、`seawater`（v3.3.5）。

```bash
pip install requests pandas seawater
```

随机种子固定为 `20261014`，结果可复现。

## 目录

交付物在以项目命名的子文件夹内，脚本与原始下载留在上一级：

```
scripts/01_fetch_woa23.py          下载 NOAA WOA23 decav91C0 气候态
scripts/02_build_density_table.py  EOS-80 复算 + 质控 + 结构化输出
scripts/03_sensitivity_scan.py     Main.qml 算法复刻 + 敏感性实验
data/raw/                          24 个原始 .csv.gz（55 MB，未改动）

面向多型潜航器的多模态空间感知与潜浮均衡协同决策系统/    ★ 交付物
├── 面向…李韦潮-王心志-王宇哲-孙子杭.md   实验报告
└── data/
    ├── seawater_density.csv          主数据集，464 行 × 23 列（276 条 QC 通过）
    ├── density_envelope.csv          按深度的密度包络
    ├── density_lookup.json           程序可调用的嵌套结构 {海区→月份→深度→{rho,u,T,S}}
    ├── qc_report.md                  质控报告
    ├── sensitivity_report.md         敏感性实验报告
    └── sensitivity_*.csv             逐条 / 扫描明细
```

脚本默认输出即指向该子文件夹（`02`、`03` 中的 `OUT`/`DATA` 常量），重跑不会在别处产生副本。

## 数据来源

| 项目 | 内容 |
| --- | --- |
| 数据集 | NOAA WOA23（World Ocean Atlas 2023），1° 网格，`decav91C0` |
| 统计期 | 1991–2020 气候态 |
| 下载地址 | `https://www.ncei.noaa.gov/data/oceans/woa/WOA23/DATA/` |
| 取样 | 4 海区 × 4 月份（1/4/7/10 月）× 29 个标准层（0–300 m） |
| 密度算法 | EOS-80（UNESCO 1983），温标 ITS-90 → IPTS-68（`T68 = 1.00024·T90`） |

## 覆盖边界（重要）

`data/` 里的密度记录**并非每个海区都有 300 m**：渤海中部至 20 m、黄海中部至 60 m、东海陆架至 125 m、南海北部至 300 m。这是实际水深决定的物理缺测，不是数据缺失，**不要向深水层外推填充**。

## 注意

- 气候态是长期平均值，**不是作业当时的实时值**。
- `dd`（Data distribution）字段的语义未经确认，仅作观测支撑强弱的相对指标使用。
- 本实验只检验**决策是否改变**，不检验决策本身的物理正确性。
