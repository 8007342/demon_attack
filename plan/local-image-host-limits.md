# Local image generation: host limits

Check this before planning asset work that depends on `image.generate`. Whether it works depends on the host, not only on the model tier.

| Host | Result |
|---|---|
| RTX A5000, 24 GB VRAM | I0 to I3 all ran (2026-11-02). Send one call at a time: concurrent calls crash the engine. |
| Intel i7-4650U, 7.7 GiB RAM | Nothing runs (2026-11-04). The engine aborts while starting its backend. |

The low-power failure:

```
ggml_vulkan: device Vulkan0 does not support 16-bit storage.
what():  Unsupported device
```

- It fails the same way at 64², 1 step, so reducing size or steps cannot help.
- The engine lists a CPU backend but does not fall back to it, and `image.generate` has no backend setting.
- The I0 download (1.3 GB) is offered and accepted before this failure shows, so on a host like this, expect to pay for a model it cannot run.
- Exit status 139 also appears for the concurrent-call crash. Read the error text to tell them apart.

**What to do on a low-power host:** keep making sprites with the deterministic `tools/generate_*.py` scripts, and run generative passes on the larger host. A CPU-only `stable-diffusion.cpp` build in the forge looks feasible but is untested, needs its own model download, and bypasses the Tillandsias pipeline.

The full record is in `FORGE_DIAGNOSTICS.md` on `research/local-image-low-power-host`.
