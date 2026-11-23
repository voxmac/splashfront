"""Builds a Kaggle script kernel that makes every BGM take of one job with ACE-Step 1.5 (MIT) on a free T4.
usage: python tools/bgm_kernel.py bgm/SF01.json <kaggle_username>  -> prints build/<id>/ (kernel.py + kernel-metadata.json)
Same ACE-Step setup as the MIDLIFE COMMUTER channel (uv env, float32 on T4), but the models load once for all tracks."""
import json, os, sys

KERNEL = r'''
import json, os, subprocess, time
SPEC = json.loads(__SPEC__)
OUT = "/kaggle/working/out/" + SPEC["id"]; os.makedirs(OUT, exist_ok=True)
ACE = "/tmp/ace"

def sh(c):
    print("$", c, flush=True); subprocess.run(c, shell=True, check=True)

t0 = time.time()
sh("pip install -q uv")
sh(f"git clone -q --depth 1 https://github.com/ace-step/ACE-Step-1.5 {ACE}")
sh(f"cd {ACE} && uv sync -q")
# T4 has no bfloat16; float16 latents overflow to NaN -> float32
sh(f"sed -i 's/self.dtype = torch.float16/self.dtype = torch.float32/' {ACE}/acestep/core/generation/handler/init_service_orchestrator.py")

GEN = """
import json, os, sys, time
sys.path.insert(0, "/tmp/ace")
from acestep.handler import AceStepHandler
from acestep.llm_inference import LLMHandler
from acestep.inference import GenerationParams, GenerationConfig, generate_music
from acestep.model_downloader import ensure_lm_model
from pathlib import Path
import torch
spec, out = json.load(open(sys.argv[1])), sys.argv[2]
dit = AceStepHandler()
msg, ok = dit.initialize_service(project_root="/tmp/ace", config_path=spec.get("dit", "acestep-v15-turbo"), device="cuda", offload_to_cpu=True)
print("DiT:", msg, flush=True); assert ok, msg
print("LM model:", ensure_lm_model(spec.get("lm", "acestep-5Hz-lm-0.6B"), Path("/tmp/ace/checkpoints")), flush=True)
llm = LLMHandler()
msg, ok = llm.initialize(checkpoint_dir="/tmp/ace/checkpoints", lm_model_path=spec.get("lm", "acestep-5Hz-lm-0.6B"),
                         backend="pt", device="cuda", offload_to_cpu=True, dtype=None)
print("LM:", msg, flush=True); assert ok, msg
rep = []
for t in spec["tracks"]:
    for i, seed in enumerate(t.get("seeds", [11, 22])):
        t1 = time.time()
        p = GenerationParams(task_type="text2music", thinking=True, caption=t["style"], lyrics=t.get("lyrics", "[Instrumental]"),
                             bpm=t.get("bpm"), keyscale=t.get("key", ""), timesignature=spec.get("time", "4"),
                             vocal_language="en", duration=t.get("duration", 90), inference_steps=t.get("steps", 8),
                             guidance_scale=1.0, seed=seed)
        torch.cuda.empty_cache()
        r = generate_music(dit, llm, params=p, config=GenerationConfig(batch_size=1, audio_format="wav"), save_dir=out)
        if not r.success:
            print("FAILED", t["name"], seed, r.status_message, flush=True); continue
        dst = f"{out}/{t['name']}_v{i + 1}.wav"; os.replace(r.audios[0]["path"], dst)
        rep.append({"track": t["name"], "version": i + 1, "seed": seed, "file": os.path.basename(dst), "seconds_to_make": round(time.time() - t1)})
        print("made", dst, round(time.time() - t1), "s", flush=True)
        json.dump(rep, open(f"{out}/takes.json", "w"), indent=1)
"""
open("/tmp/bgm_gen.py", "w").write(GEN); json.dump(SPEC, open("/tmp/bgm_spec.json", "w"))
sh(f"cd {ACE} && PYTORCH_ALLOC_CONF=expandable_segments:True .venv/bin/python /tmp/bgm_gen.py /tmp/bgm_spec.json {OUT}")
takes = json.load(open(f"{OUT}/takes.json"))
for tk in takes:   # mp3 for listening on a phone; the wav goes to the loop editor
    w = f"{OUT}/{tk['file']}"; sh(f'ffmpeg -loglevel error -y -i "{w}" -b:a 192k "{w[:-4]}.mp3"')
json.dump({"id": SPEC["id"], "takes": takes, "minutes_total": round((time.time() - t0) / 60, 1)}, open(f"{OUT}/report.json", "w"), indent=1)
print("DONE", OUT, flush=True)
'''


def main():
    spec_path, user = sys.argv[1], sys.argv[2]
    spec = json.load(open(spec_path, encoding="utf-8"))
    d = os.path.join("build", spec["id"]); os.makedirs(d, exist_ok=True)
    src = KERNEL.replace("__SPEC__", repr(json.dumps(spec, ensure_ascii=False)))
    open(os.path.join(d, "kernel.py"), "w", encoding="utf-8").write(src)
    slug = f"splashfront-bgm-{spec['id'].lower()}"
    json.dump({"id": f"{user}/{slug}", "title": slug, "code_file": "kernel.py", "language": "python", "kernel_type": "script",
               "is_private": True, "enable_internet": True, "enable_gpu": True, "machine_shape": "NvidiaTeslaT4",
               "dataset_sources": [], "competition_sources": [], "kernel_sources": [], "model_sources": []},
              open(os.path.join(d, "kernel-metadata.json"), "w"), indent=1)
    print(d)


if __name__ == "__main__":
    main()
