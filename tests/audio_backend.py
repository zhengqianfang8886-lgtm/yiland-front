#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from typing import Any, Dict, List
import pulsectl


class AudioBackend:

    def __init__(self):
        # 初始化与 PulseAudio / PipeWire-Pulse 的连接
        self.client_name = "kde-audio-backend"

    def get_audio_info(self) -> Dict[str, List[Dict[str, Any]]]:
        """获取所有音频输出（播放设备）和输入（录音/话筒设备）的状态信息"""
        with pulsectl.Pulse(self.client_name) as pulse:
            server_info = pulse.server_info()
            default_sink_name = server_info.default_sink_name
            default_source_name = server_info.default_source_name

            # 1. 获取输出设备 (Sinks / Speakers)
            outputs = []
            for sink in pulse.sink_list():
                # 计算音量百分比 (取通道平均值)
                volume_pct = round(sink.volume.value_flat * 100)

                outputs.append(
                    {
                        "index": sink.index,
                        "name": sink.name,
                        "description": sink.description,  # 对应截图中的设备名
                        "volume": volume_pct,  # 对应截图中的百分比 (e.g. 28)
                        "muted": bool(sink.mute),  # 对应截图中的静音状态
                        "is_default": (
                            sink.name == default_sink_name
                        ),  # 对应截图中的蓝色选中小圆点
                    }
                )

            # 2. 获取输入设备 (Sources / Microphones)
            inputs = []
            for source in pulse.source_list():
                # 过滤掉系统内部的 monitor 监视器设备（只保留物理/虚拟麦克风）
                if source.name.endswith(".monitor"):
                    continue

                volume_pct = round(source.volume.value_flat * 100)

                inputs.append(
                    {
                        "index": source.index,
                        "name": source.name,
                        "description": source.description,  # 对应截图中的话筒名
                        "volume": volume_pct,  # 对应截图中的百分比 (e.g. 94)
                        "muted": bool(source.mute),
                        "is_default": (source.name == default_source_name),
                    }
                )

            return {"outputs": outputs, "inputs": inputs}

    # ================= 控制接口扩展 =================

    def set_volume(
        self, index: int, volume_pct: int, is_input: bool = False
    ) -> None:
        """设置音量 (volume_pct: 0 - 100)"""
        with pulsectl.Pulse(self.client_name) as pulse:
            target = (
                pulse.source_get(index) if is_input else pulse.sink_get(index)
            )
            # volume_pct 转换为 0.0 ~ 1.0 的浮点数
            pulse.volume_set_all_chans(target, volume_pct / 100.0)

    def set_mute(self, index: int, mute: bool, is_input: bool = False) -> None:
        """设置静音状态"""
        with pulsectl.Pulse(self.client_name) as pulse:
            target = (
                pulse.source_get(index) if is_input else pulse.sink_get(index)
            )
            pulse.mute(target, mute)

    def set_default_device(self, name: str, is_input: bool = False) -> None:
        """设置默认设备（点击蓝色圆点切换）"""
        with pulsectl.Pulse(self.client_name) as pulse:
            if is_input:
                pulse.default_set(pulse.get_source_by_name(name))
            else:
                pulse.default_set(pulse.get_sink_by_name(name))


# ================= 测试运行 =================
if __name__ == "__main__":
    import json

    backend = AudioBackend()
    data = backend.get_audio_info()

    # 格式化打印当前状态
    print(json.dumps(data, indent=4, ensure_ascii=False))
