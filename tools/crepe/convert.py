# CREPE-tiny → CoreML 转换脚本(存档:当前转换数值保真度未达标,勿直接上线)。
#
# 状态:
# - 模型加载/trace/转换流程跑通(486k 参数,输出 [1,360] 激活);
# - torchcrepe 官方 predict 参考输出正常(196Hz 合成音 → 196.8Hz);
# - 但 PyTorch eager 与 CoreML 输出不一致(同帧:78.96Hz vs 184.58Hz),
#   疑似 std/clamp 或非对称 conv padding 的 MLProgram 转换数值问题。
# 使用:python3 -m venv env && pip install torch coremltools torchcrepe && python convert.py
import os
import torch
import torchcrepe
import coremltools as ct

class Wrapped(torch.nn.Module):
    """逐帧零均值/单位方差归一化(torchcrepe 预处理)包进模型。"""
    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, x):
        x = x - x.mean(dim=-1, keepdim=True)
        std = x.std(dim=-1, keepdim=True).clamp_min(1e-5)
        return self.m(x / std)

def build():
    model = torchcrepe.Crepe('tiny')
    weights = os.path.join(os.path.dirname(torchcrepe.__file__), 'assets', 'tiny.pth')
    model.load_state_dict(torch.load(weights, map_location='cpu', weights_only=True))
    return Wrapped(model).eval()

if __name__ == '__main__':
    import numpy as np
    wrapped = build()
    traced = torch.jit.trace(wrapped, torch.randn(1, 1024))
    ml = ct.convert(
        traced,
        inputs=[ct.TensorType(name="audio", shape=(1, 1024), dtype=np.float32)],
        compute_precision=ct.precision.FLOAT32,
        minimum_deployment_target=ct.target.iOS17,
    )
    ml.save("CrepeTiny.mlpackage")
    print("saved CrepeTiny.mlpackage — 请先做逐帧与 PyTorch 的一致性验证再考虑集成")
