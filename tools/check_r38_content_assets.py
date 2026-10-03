#!/usr/bin/env python3
"""Verify the shipped expansion art and its preserved original pose sheets."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
ACTORS = ['hero_solar_lancer','hero_tide_oracle','hero_shadow_ronin','enemy_dune_scarab','enemy_sand_stalker','enemy_tide_siren','enemy_coral_colossus','enemy_bloom_wisp','enemy_clockwork_reaper']

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    manifest=json.loads((ROOT/'assets/art/r38/source_manifest.json').read_text(encoding='utf-8'))
    assert manifest['original_actor_count']==9 and manifest['original_pose_count']==144
    assert digest(ROOT/manifest['atlas'])==manifest['atlas_sha256']
    records={item['id']:item for item in manifest['actors']}
    for actor in ACTORS:
        item=records[actor]
        assert item['source_pose_count']==16
        assert digest(ROOT/item['source'])==item['source_sha256'], actor
        assert (ROOT/f'assets/sprites/{actor}.png').is_file(), actor
    for name in ['tile_desert.png','tile_coral.png','tile_clockwork.png','landmarks.png']:
        assert (ROOT/'assets/art/r38'/name).is_file(), name
    catalog=(ROOT/'scripts/services/stage_catalog.gd').read_text(encoding='utf-8')
    ids=re.findall(r'\{"id"\s*:\s*"([^"]+)"',catalog)
    assert len(ids)==10 and len(set(ids))==10,ids
    print('R38_CONTENT_ASSETS_PASS actors9=true originalposes144=true source_hashes=true runtime_atlas=true stages10=true')

if __name__=='__main__':
    main()
