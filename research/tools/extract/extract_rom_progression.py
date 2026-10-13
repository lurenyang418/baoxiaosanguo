#!/usr/bin/env python3
"""Extract ROM experience rewards and promotion thresholds/branches."""
import argparse,json
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path);p.add_argument('--output',type=Path,default=Path('data/rom_progression.json'));a=p.parse_args();image=a.rom.read_bytes()
 if image[:4]!=b'NES\x1a': raise ValueError('Not an iNES ROM')
 def read(bank,cpu,n):
  start=16+bank*0x4000+cpu-0x8000;b=image[start:start+n]
  if len(b)!=n: raise ValueError('Truncated ROM')
  return b
 assert read(2,0x9668,4)==bytes.fromhex('38 bd f7 65')
 assert read(10,0x8F86,5)==bytes.fromhex('b1 1e 9d 3f 64')
 branches=[]
 for selector in range(13):
  ptr=int.from_bytes(read(10,0x901F+selector*2,2),'little');count=read(10,0x8FB7+selector*8+6,1)[0]
  branches.append({'selector':selector,'choices':list(read(10,ptr,count)),'pointer_cpu':f'${ptr:04X}'})
 records=[]
 for t in range(72):
  raw=read(8,0x8B7C+t*13,13);threshold=int.from_bytes(read(2,0x97AD+t*2,2),'little');selector=read(2,0x983F+t,1)[0]
  choices=[] if threshold==65535 else [t+1] if selector==255 else branches[selector]['choices']
  records.append({'unit_type_id':t,'next_experience_threshold':threshold,'branch_selector':selector,'promotion_choices':choices,'movement_points':raw[7],'attack_experience':raw[10],'technique_experience':raw[11],'kill_experience':raw[12]})
 result={'source':'Original ROM static control flow and tables','experience_arrays':{'battle':'$65F7/$65F8','roster':'$652F/$6530'},'thresholds':{'bank':2,'cpu':'$97AD','comparison_cpu':'$9657-$9675'},'branches':{'selector_bank':2,'selector_cpu':'$983F','choices_bank':10,'pointer_cpu':'$901F','records':branches},'rewards':{'attack_cpu':'bank2 $8F86-$8FA1','technique_cpu':'bank8 $9A41-$9A5E','kill_cpu':'bank2 $8FD4-$8FEF and bank8 $9B16-$9B33','interpretation':'Caster definition bytes 10/11/12; technique reward once per nonempty target list, kill reward per defeated target; accumulated 16-bit experience is not reset.'},'hp_update':{'cpu':'bank2 $9694-$96A7; bank10 $8F95-$8FAA; bank8 $81E9-$8200','interpretation':'New HP equals new maximum minus previous missing HP. Stat reload skips experience fields.'},'limitations':'Static decoding; player command dispatcher checks promotion once after attack/technique. Original promotion presentation not reconstructed.','records':records}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__': main()
