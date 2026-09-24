---
title: "新生杯电赛：从零搭一台 STM32 智能盆栽管家"
date: 2026-09-24
draft: false
tags: ["STM32", "嵌入式", "电子设计大赛", "硬件", "实战经验"]
categories: ["个人项目"]
---

> 一块洞洞板、一颗 STM32F103C8T6、一个 0.96 寸 OLED——把「浇水」这件小事做成一套能自证的闭环系统

---

## 一、缘起：新生杯 A 题

大一上学期，学院新生杯电子设计大赛。A 题的题目叫「智能盆栽管家」，要求很具体：

| 模块 | 要求 |
|---|---|
| 基础① | 实时采集土壤湿度 + 环境光照，在显示屏上分区/分页显示 |
| 基础② | 三个独立按键：切换自动/手动、手动开关补光灯、手动开关水泵；湿度低于安全阈值时**声光报警** |
| 基础③ | 自动模式下：光照低于 $L_{min}$ 开补光灯、高于 $L_{max}$ 关；湿度低于阈值自动开泵浇水 3 秒 |
| 发挥① | 每 10s 记录一组数据，按键分页查看过去 1 分钟趋势 |
| 发挥② | 接入小型太阳能板 + 电源管理电路，实现充电与切换供电 |

我和队友王程毅（25 自动化）两个人，从画原理图到写固件，做完了这套系统，最后拿了**三等奖**。

这篇不写论文式流水账，只记录真正做出来的东西、代码里真实存在的逻辑，以及回头看时那些当时没意识到的问题。

---

## 二、系统方案

### 选型：为什么是 STM32

题目允许 51，但 51 的资源撑不住我们要的功能：多路 ADC 采样 + I2C 驱动 OLED + PWM 调光 + 历史数据缓冲 + 分页界面，同时在跑。STM32F103C8T6 是 Cortex-M3、72MHz、64KB Flash / 20KB RAM，外设够用、价格够低、资料够多，是这类题目的标准答案。

> 顺便记一条赛题规则：**用现成核心板会扣设计报告里「电路设计」的 3 分**。所以最小系统、电源、驱动这几块我们都自己画了原理图并打板。

### 整体框图

{{< figure src="block-diagram.png" alt="系统整体框图" caption="系统整体框图：感知 → 主控 → 执行 + 显示" >}}

### 电源：太阳能 + 双 18650 切换

发挥部分第②项要求的电源管理，我们做的是**双电池切换**而不是简单的二极管并联：

- 5V 太阳能板 + 充电管理芯片给 18650 电池充电
- 光照充足时：电池 A 充电，电池 B 供电
- 光照不足时：切到电池 A 供电，且**电池 A 在供电期间不允许充电**（避免边充边放）
- 切换靠运放把光照采样值与 3.3V 基准比较，输出驱动 PMOS / NMOS 完成通路切换
- 最后经 LDO 稳压到 3.3V 给整个系统

{{< figure src="power-switch.png" alt="电源切换原理图" caption="电源切换：运放比较 + PMOS/NMOS 双路互锁" >}}

{{< figure src="ldo.png" alt="LDO 降压电路" caption="LDO 降压：5V → 3.3V，输出并联 22µF + 0.1µF 滤波" >}}

### 感知与执行

- **土壤湿度**：湿敏电阻与固定电阻分压 → PA3，走 ADC1_IN3
- **环境光照**：光敏电阻与 10K 分压 → PA4，走 ADC1_IN4
- **补光灯**：PB10 输出 PWM（TIM2_CH3，部分重映射 2）→ 15K 限流 → NMOS，用占空比调亮度
- **微型水泵**：PB12 → NMOS，纯开关控制
- **报警**：PA5 → 红色 LED

{{< figure src="sensor.png" alt="传感器电路" caption="湿敏 / 光敏分压采样电路" >}}

{{< figure src="driver.png" alt="驱动电路" caption="补光灯 PWM 调光 + 水泵开关，均由 NMOS 驱动" >}}

### 人机交互

0.96 寸 OLED（SSD1306 12864），I2C 接 PB6/PB7，地址 `0x78`。四个独立按键：

| 按键 | 引脚 | 功能 |
|---|---|---|
| KEY_MODE | PA8 | 自动 / 手动切换 |
| KEY_LIGHT | PB13 | 手动开关补光灯 |
| KEY_PUMP | PB14 | 手动开关水泵（最终改由 PA9 承担） |
| KEY_RECORD | PB15 | 查看历史数据 / 翻页 |

{{< figure src="board-min-system.png" alt="STM32 最小系统" caption="STM32F103C8T6 最小系统：8MHz 晶振、复位、SWD、去耦电容" >}}

{{< figure src="flow-key.jpeg" alt="按键功能流程图" caption="按键功能总流程图" >}}

---

## 三、固件设计

### 主循环：一切以 2 秒为节拍

固件没有用 RTOS，就是一个大循环 + 定时触发。核心结构：

```c
while (1)
{
  KEY_Value key = Key_Scan();               // 按键扫描（阻塞式，带防抖）

  uint8_t pa9_now = HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_9);
  if (pa9_last == 1 && pa9_now == 0) {      // 下降沿 → 手动浇水
    if (work_mode == MODE_MANUAL) { /* 动画 + 开泵 3s */ }
  }
  pa9_last = pa9_now;

  switch (key) { /* 模式切换 / 历史页 / 手动补光 */ }

  if (HAL_GetTick() - oled_refresh_tick >= 2000) {  // 2 秒一次
    oled_refresh_tick = HAL_GetTick();
    OLED_Show();   // 采集 + 显示 + 存历史
    Auto_Run();    // 自动控制
  }

  HAL_Delay(30);
}
```

为什么是 2 秒？因为一次完整的采集本身就慢（下面会讲），再快也没有意义，而 2 秒的节拍对盆栽这种慢变量完全够用。

### ADC：20 次平均换稳定性

土壤和光照都是慢变量，但单次 ADC 读数跳动明显。做法是同一通道连续采 20 次求平均，采样时间拉到 239.5 个周期：

```c
uint32_t Get_ADC(uint32_t ch)
{
  uint32_t sum = 0;
  for (uint8_t i = 0; i < SAMPLE_NUM; i++)   // SAMPLE_NUM = 20
  {
    sConfig.Channel = ch;
    sConfig.SamplingTime = ADC_SAMPLETIME_239CYCLES_5;
    HAL_ADC_ConfigChannel(&hadc1, &sConfig);
    HAL_ADC_Start(&hadc1);
    HAL_ADC_PollForConversion(&hadc1, 50);
    sum += HAL_ADC_GetValue(&hadc1);
    HAL_ADC_Stop(&hadc1);
    HAL_Delay(5);
  }
  return sum / SAMPLE_NUM;
}
```

### 把 ADC 值翻译成人能看懂的数

原始 ADC 值（0~4095）没有意义，要映射成百分比。两个传感器的方向是**相反**的，这里必须想清楚：

- 土壤越湿 → 湿敏电阻越小 → 分压越小 → ADC 越小 → 湿度百分比**越高**
- 光照越强 → 光敏电阻越小 → 分压越小 → ADC 越小 → 光照百分比**越高**（代码里是 `100 - adc*100/4095`）

```c
#define DRY_ADC   3300   // 土壤干燥时的 ADC 值
#define WET_ADC   1300   // 土壤湿润时的 ADC 值

uint8_t Get_Humi(void)
{
  uint32_t adc = Get_ADC(ADC_CHANNEL_3);
  if (adc >= DRY_ADC) return 0;     // 极干
  if (adc <= WET_ADC) return 100;   // 极湿
  return (uint8_t)((DRY_ADC - adc) * 100UL / (DRY_ADC - WET_ADC));
}
```

`3300` 和 `1300` 这两个标定值不是算出来的，是拿干土和湿土各测一遍记下来的——**传感器标定只能靠实测，不能靠手册**。

### 自动控制：阈值 + 线性调光

```c
#define HUMI_WATER  30    // 低于 30% 自动浇水
#define LIGHT_LOW   60    // 低于 60% 自动补光

void Auto_Run(void)
{
  if (work_mode != MODE_AUTO) return;

  if (humi < HUMI_WATER) {                     // 自动浇水 2 秒
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12, GPIO_PIN_SET);
    HAL_Delay(2000);
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_12, GPIO_PIN_RESET);
  }

  if (light < LIGHT_LOW) {                     // 光照不足 → PWM 补光
    uint16_t pwm_val = (LIGHT_LOW - light) * 900 / LIGHT_LOW;
    if (pwm_val > 999) pwm_val = 999;
    __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_3, pwm_val);
  } else {
    __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_3, 0);
  }
}
```

补光不是简单的开关，而是**缺多少光补多少亮**：光照 0% 时占空比拉满到 90%，接近 60% 时逐渐熄灭。

PWM 参数：TIM2 预分频 71、自动重装 999，72MHz 主频下得到 **1kHz** 的调光频率——足够高，人眼看不到闪烁。

### 历史数据：10 秒一条的环形缓冲

发挥部分要求记录 1 分钟趋势。做法很朴素：6 个槽位的环形缓冲区，每 10 秒写一条，写满覆盖最旧的。

```c
#define RECORD_INTERVAL  10000   // 10 秒一条
#define MAX_RECORDS      6       // 6 条 = 1 分钟

typedef struct { uint8_t humidity; uint8_t light; } DataRecord;
DataRecord record_buffer[MAX_RECORDS];
```

OLED 上每页显示 3 条，两页翻完。没数据时显示 `NO data / wait plz`，而不是空白——**空状态要说清楚，别让用户以为是坏了**。

{{< figure src="flow-history.jpeg" alt="历史数据显示流程图" caption="历史数据：分页查看流程图" >}}

### 交互细节：让机器「有话可说」

这一块是最容易被忽略、但答辩时最加分的地方。

**浇水动画**：手动浇水时，屏幕上的水滴会一帧一帧往下落：

```c
void Watering_Animation(void)
{
  for (uint8_t y = 1; y <= 4; y++) {
    OLED_Clear();
    OLED_ShowString(5, y, ".");                  // 水滴下落
    OLED_ShowString(0, 5, "watering........");
    HAL_Delay(300);
  }
  OLED_Clear();
}
```

{{< figure src="flow-water.jpeg" alt="手动浇水流程图" caption="手动浇水（PA9 下降沿触发）流程图" >}}

**开机画面**：`Smart Plant / System Ready / f8fq 4.0`，给 1.5 秒让屏幕醒过来。

**报警联动**：湿度低于 20% 时，屏幕打出 `!!! DRY !!!` 同时点亮 PA5 红色 LED；正常时显示 `NORMAL`。

{{< figure src="flow-main.jpeg" alt="主程序流程图" caption="主程序流程图" >}}

{{< figure src="flow-auto.jpeg" alt="自动模式流程图" caption="自动模式：浇水与补光决策流程" >}}

---

## 四、实物与实测

{{< figure src="photo-overall.jpeg" alt="作品整体图" caption="作品整体：太阳能板、双 18650、主控板、水泵、传感器" >}}

{{< figure src="photo-detail.png" alt="作品局部" caption="局部：补光灯点亮状态与水泵" >}}

**实时界面**（湿度归零触发报警的实测画面）：

{{< figure src="oled-realtime.png" alt="OLED 实时界面" caption="实时界面：Humi 0% / Light 93% / !!! DRY !!!" >}}

**历史界面**（正常土壤湿度下的 3 条记录）：

{{< figure src="oled-history.png" alt="OLED 历史界面" caption="历史界面：Humi 67/60/59%，Light 91/92/91%" >}}

上电后实测：湿度响应、光照响应、自动浇水、PWM 调光、报警 LED、历史分页均正常工作，系统连续运行稳定。

---

## 五、回头看：三个当时没意识到的问题

写这篇的时候把固件重读了一遍，有几处问题当时没感觉，现在很扎眼：

### 1. 阻塞式延时把整个系统卡住了

`Get_ADC()` 里 20 次采样各带 `HAL_Delay(5)`，一次湿度采集至少 100ms；`OLED_Show()` 要采两次（湿度+光照），就是 200ms。自动浇水更狠——`HAL_Delay(2000)` 直接把主循环冻住 2 秒。

**后果**：浇水那 2 秒里，按键完全无响应。

**现在会怎么做**：用状态机 + 时间戳，把「浇水 2 秒」拆成「开泵 → 记录时刻 → 到点关泵」，主循环一刻不停。

### 2. 赛题要求的「声光报警」只落地了一半

赛题原文是「蜂鸣器鸣响、红色 LED 闪烁」。最终固件里能查到的只有 **PA5 红色 LED 常亮**——没有蜂鸣器驱动，也没有闪烁逻辑。

**教训**：验收清单要对着题目逐条打勾。声光报警是 15 分的基础项，漏掉的是可量化的分。

### 3. 自动浇水固定 2 秒，和题目写的 3 秒对不上

赛题写「自动开启水泵 3 秒」，`Auto_Run()` 里是 `HAL_Delay(2000)`；而手动浇水反而是 3 秒。同一件事两个参数，属于典型的没对齐。

---

## 六、小结

这套东西的技术含量不算高——分压采样、阈值判断、PWM 调光，都是教科书里的东西。但**从原理图、打板、焊洞洞板到固件跑通**，整条链路自己走一遍，收获比抄十个例程都大：

- 传感器标定必须实测，手册给不了你的阈值
- 慢变量的系统，**稳定比快重要**（20 次平均换来的平滑曲线，比 1 秒刷新一次的跳数有用得多）
- 交互细节是「演示分」——水滴动画、无数据提示、开机画面，成本极低，观感差距极大
- 验收要对着赛题逐条打勾，别用「我做了个更酷的」代替「题目要的那个」

三等奖不算亮眼，但这块板子是我第一套**完整闭环**的嵌入式系统：有输入（传感器）、有决策（阈值+状态机）、有输出（水泵/灯/屏）、有记忆（历史数据）。后面的路都从它开始。

---

**参考资料**

- STMicroelectronics. *STM32F103C8T6 Datasheet*. 2016.
- 王田苗. 《嵌入式系统设计与实践》. 电子工业出版社, 2020.
- 吴金戌. 《传感器原理及工程应用》. 西安电子科技大学出版社, 2018.
