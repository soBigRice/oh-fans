<!--
 * @Author: superRice
 * @Date: 2026-04-23 11:29:23
 * @LastEditors: superRice 1246333567@qq.com
 * @LastEditTime: 2026-04-23 18:01:57
 * @FilePath: /iFans/README.md
 * @Description:
 * Do your best to be yourself
 * Copyright (c) 2026 by superRice, All Rights Reserved.
-->
<p align="center">
  <img src="iFans/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" alt="oh fans app icon" width="128">
</p>

<h1 align="center">oh fans</h1>

<p align="center">给 Apple Silicon Mac 用的菜单栏风扇控制工具</p>

<p align="center">
  <img src="https://img.shields.io/badge/Apple_Silicon-M_Series_Only-111111?style=for-the-badge&logo=apple&logoColor=white" alt="Apple Silicon only">
  <img src="https://img.shields.io/badge/Menu_Bar-Quick_Control-0f172a?style=for-the-badge&logo=apple&logoColor=white" alt="Menu bar quick control">
  <img src="https://img.shields.io/badge/Auto_Manual-Easy_Switch-1f2937?style=for-the-badge&logo=swift&logoColor=white" alt="Auto and manual mode">
  <img src="https://img.shields.io/badge/Helper-Real_Fan_Control-374151?style=for-the-badge&logo=apple&logoColor=white" alt="Helper for real control">
</p>

<p align="center">
  <a href="https://github.com/soBigRice/oh-fans/releases/latest">
    <img src="https://img.shields.io/badge/Download-Latest_Release-16a34a?style=for-the-badge&logo=github&logoColor=white" alt="Download latest oh fans release">
  </a>
</p>

`oh fans` 是一个面向 M 系列 Mac 的菜单栏风扇控制工具。它不只是把风扇数据展示出来，还把真正可用的控制链路、状态反馈和常用操作都收进了一个轻量的桌面应用里。

## 😏 为什么做这个

很多风扇软件我用着都不太顺手。

有的功能不少，但操作路径像走迷宫；有的界面看着就很有压迫感，调个风扇像准备起飞；还有的我点了半天，最后怀疑不是风扇在转，是我的血压在转。

刚好那天心血来潮，就自己写了一个。

没什么宏大愿景，单纯就是想做个自己愿意天天开着用的软件：打开快一点，操作直接一点，别每次调风扇都像在和电脑谈判。

<table align="center">
  <tr>
    <td align="center" width="180">
      <strong>🍎 Apple Silicon</strong><br>
      只支持 M 系列 Mac
    </td>
    <td align="center" width="180">
      <strong>🌀 菜单栏常驻</strong><br>
      左键控制，右键快捷菜单
    </td>
    <td align="center" width="180">
      <strong>🎛️ 模式切换</strong><br>
      自动与手动快速切换
    </td>
  </tr>
  <tr>
    <td align="center" width="180">
      <strong>✨ 预设直达</strong><br>
      常用档位一键切换
    </td>
    <td align="center" width="180">
      <strong>🧩 辅助控件</strong><br>
      用于真正写入风扇控制
    </td>
    <td align="center" width="180">
      <strong>🔎 状态反馈</strong><br>
      异常时直接给出提示
    </td>
  </tr>
</table>

## 🍎 适用范围

- 仅支持 Apple Silicon（M1 / M2 / M3 / M4 及后续 M 系列）Mac
- 不支持 Intel Mac

## 📦 下载安装

- 下载地址：[点击下载](https://github.com/soBigRice/oh-fans/releases/latest)
- 首次安装如果被 macOS 拦截，请查看 [打不开时的处理说明](docs/README_如果打不开请看这里.md)

## ✨ 主要功能

- 菜单栏常驻，随时查看和操作风扇状态
- 左键打开紧凑控制面板，右键打开“设置 / 退出”快捷菜单
- 支持自动与手动控制模式切换
- 支持常用预设切换，减少重复设置
- 支持“高透 / 正常”两种界面样式
- 支持在主界面和设置页查看辅助控件状态、版本信息和重装入口
- 当控制链路异常时，直接给出明确提示，而不是只有“点了没反应”

## 🖱️ 使用方式

- 左键菜单栏图标：打开紧凑控制面板
- 右键菜单栏图标：打开快捷菜单
- 在设置页可以查看当前状态、切换界面样式、检查辅助控件状态

## 🧩 关于辅助控件

macOS 不允许普通应用直接写 AppleSMC 的风扇控制键，所以 `oh fans` 在真正控制风扇时需要依赖辅助控件完成底层操作。

- 没有辅助控件时，应用仍可打开，但只保留监控能力
- 辅助控件缺失、损坏或版本不匹配时，界面会自动提示安装或重装
- 辅助控件恢复正常后，就可以继续使用真实风扇控制能力

## 📌 当前边界

- 当前只支持 Apple Silicon，不支持 Intel Mac
- 辅助控件不可用时，会自动退回监控模式
- GitHub 上的未签名测试版首次打开时，macOS 可能拦截；这种情况请查看 [打不开时的处理说明](docs/README_如果打不开请看这里.md)
