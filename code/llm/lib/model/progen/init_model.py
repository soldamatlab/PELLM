import sys
import os
from pathlib import Path

import torch

from lib.model.progen.path import PROGEN_PATH

MODEL_PATH = PROGEN_PATH + "progen/progen2/checkpoints/progen2-small"


def init_model(lm=False):
    parent_dir = os.path.dirname(Path(__file__))
    sys.path.append(parent_dir + "/" + PROGEN_PATH)
    if lm:
        from progen.progen2.models.progen.modeling_progen import ProGenForCausalLM
    else:
        from progen.progen2.models.progen.modeling_progen import ProGenModel

    path = parent_dir + "/" + MODEL_PATH

    if lm:
        model = ProGenForCausalLM.from_pretrained(
            path,
            revision="float16",
            torch_dtype=torch.float32,
            low_cpu_mem_usage=False,
        )
    else:
        model = ProGenModel.from_pretrained(
            path,
            revision="float16",
            torch_dtype=torch.float32,
            low_cpu_mem_usage=False,
        )

    return model
