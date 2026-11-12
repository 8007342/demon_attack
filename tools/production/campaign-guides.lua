return {
 id='campaign-guides-2026-11-12', checkpoint=true,
 inputs={'art/music/campaign.json','tools/campaign_guide.py','tools/music_guide.py','tools/music_motifs.py','tools/production/guide_job.lua'},
 jobs={
  {id='level-1',argv={'lua','tools/production/guide_job.lua','1'},outputs={'assets/research/battle-metal-radio/batch-2026-11-12/guides/level-1.json'}},
  {id='level-2',argv={'lua','tools/production/guide_job.lua','2'},outputs={'assets/research/battle-metal-radio/batch-2026-11-12/guides/level-2.json'}},
  {id='level-3',argv={'lua','tools/production/guide_job.lua','3'},outputs={'assets/research/battle-metal-radio/batch-2026-11-12/guides/level-3.json'}},
  {id='level-4',argv={'lua','tools/production/guide_job.lua','4'},outputs={'assets/research/battle-metal-radio/batch-2026-11-12/guides/level-4.json'}},
  {id='level-5',argv={'lua','tools/production/guide_job.lua','5'},outputs={'assets/research/battle-metal-radio/batch-2026-11-12/guides/level-5.json'}},
 }
}
