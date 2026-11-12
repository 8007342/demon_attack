return {
  id='voice-trial-2026-11-12', checkpoint=true,
  inputs={'tools/production/voice_job.lua','tools/comms_pipeline.py',
    'art/comms/cast.json','art/comms/lines.json','art/comms/audio.json'},
  jobs={
    {id='reference-pip', argv={'lua','tools/production/voice_job.lua','refs','pip'},
      outputs={'assets/research/battle-metal-radio/forge-trial/voices/reference-pip.wav',
        'assets/research/battle-metal-radio/forge-trial/voices/refs.json'}},
    {id='pip-teasing', argv={'lua','tools/production/voice_job.lua','expressive','sectorStart.h4'},
      outputs={'assets/research/battle-metal-radio/forge-trial/voices/sectorStart.h4.wav',
        'assets/research/battle-metal-radio/forge-trial/voices/sectorStart.h4.key'}},
    {id='pip-urgent', argv={'lua','tools/production/voice_job.lua','expressive','diveWarning.h4'},
      outputs={'assets/research/battle-metal-radio/forge-trial/voices/diveWarning.h4.wav',
        'assets/research/battle-metal-radio/forge-trial/voices/diveWarning.h4.key'}},
    {id='pip-calm', argv={'lua','tools/production/voice_job.lua','expressive','waveStart.h5'},
      outputs={'assets/research/battle-metal-radio/forge-trial/voices/waveStart.h5.wav',
        'assets/research/battle-metal-radio/forge-trial/voices/waveStart.h5.key'}},
  },
}
