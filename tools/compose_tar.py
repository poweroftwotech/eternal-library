"""Original 'A Quiet Page': a 96-second tar-inspired plucked-string composition.
No sampled recordings. Paired strings, plectrum attacks, body modes, ornaments.
The melody uses a neutral second; it is not a transcription of a radif gusheh.
"""
from pathlib import Path
import json, wave
import numpy as np
from scipy.signal import iirpeak, lfilter, butter, sosfilt
R=np.random.default_rng(101072); SR=44100; SECONDS=96; N=SR*SECONDS
DEST=Path(__file__).resolve().parents[1]/'assets'
# Relative cents from D: a neutral second gives the melody its modal inflection.
CENTS=[0,150,300,500,700,1000,1200,1350,1500,1700]
ROOT=146.83238396
stereo=np.zeros((N,2),dtype=np.float64); score=[]

def pluck(frequency,vel=.65,decay=2.5,direction=1):
 t=np.arange(int(SR*5.5))/SR
 y=np.zeros_like(t)
 position=.17+R.uniform(-.02,.02)
 for cents,gain in [(-1.8,.54),(2.2,.46)]:
  f=frequency*2**(cents/1200)
  phase=2*np.pi*f*(t+.0006*np.sin(2*np.pi*5.1*t)*np.clip((t-.25)*1.5,0,.6))
  for k in range(1,27):
   amp=np.sin(np.pi*k*position)/(k**1.12)
   tau=decay/(1+.045*k**1.52)
   y+=gain*amp*np.cos(k*phase*np.sqrt(1+.000018*k*k)+direction*k*.03)*np.exp(-t/tau)
 y*=1-np.exp(-t/.0016)
 # The short plectrum/skin transient is per-note, never a continuous noise bed.
 noise=R.normal(0,1,len(t))*np.exp(-t/.006)
 noise=sosfilt(butter(2,[650,5000],fs=SR,btype='bandpass',output='sos'),noise)
 y+=noise*.065
 body=np.zeros_like(y)
 for hz,q,gain in [(180,3,.20),(370,4,.16),(730,5,.10),(1450,7,.055)]:
  b,a=iirpeak(hz,q,fs=SR);body+=lfilter(b,a,y)*gain
 y=(y*.76+body)*vel
 y*=np.minimum(1,(5.5-t)/.12)
 return y

def note(at,degree,vel=.65,register=1,decay=2.1,pan=-.08):
 f=ROOT*2**register*2**(CENTS[degree]/1200)
 y=pluck(f,vel,decay,1 if len(score)%2 else -1)
 start=int((at+R.uniform(-.018,.018))*SR)%N
 # Modulo accumulation wraps the previous phrase's reverberation into the loop.
 indices=(start+np.arange(len(y)))%N
 angle=(pan+1)*np.pi/4
 stereo[indices,0]+=y*np.cos(angle);stereo[indices,1]+=y*np.sin(angle)
 score.append({'time':round(at,3),'degree':degree,'register':register,'velocity':round(vel,3)})

motifs=[
 [(0.7,0),(1.65,1),(2.3,2),(3.55,3),(4.45,2),(5.10,1),(6.25,0)],
 [(0.6,2),(1.45,3),(2.50,4),(3.35,3),(4.30,2),(5.25,1),(6.10,0)],
 [(0.75,3),(1.70,4),(2.55,5),(3.55,4),(4.30,3),(5.10,2),(6.4,3)],
 [(0.55,5),(1.60,6),(2.65,5),(3.45,4),(4.50,3),(5.45,2),(6.35,1)],
 [(0.8,2),(1.55,3),(2.30,2),(3.40,1),(4.35,0),(5.55,1),(6.35,0)],
 [(0.65,3),(1.6,2),(2.6,1),(3.65,0),(5.2,0)],
]
for phrase in range(12):
 base=phrase*8
 motif=motifs[phrase%6]
 note(base+.10,0,.19,0,2.6,-.20)
 if phrase%3!=2:note(base+3.1,3,.10,0,1.7,.16)
 for j,(at,degree) in enumerate(motif):
  velocity=R.uniform(.42,.60)*(1.03 if phrase<6 else .90)
  if j==3 and phrase%3==0:
   # Gentle riza-like repeated plectrum strokes at phrase peaks.
   for k in range(4):note(base+at+k*.095,degree,velocity*(.53+.07*(k%2)),1,1.3,-.06)
  else:
   if j in [2,5] and degree>0 and phrase%2==0:
    note(base+at-.115,degree-1,velocity*.46,1,.8,-.08)
   note(base+at,degree,velocity,1,2.0+R.uniform(-.25,.25),-.08)
# A quiet, small stone-room reflection field; no sustained pad or humming tone.
dry=stereo.copy()
for delay,gain in [(.039,.11),(.071,.085),(.113,.065),(.173,.050),(.263,.037),(.397,.026),(.601,.018),(.853,.012)]:
 stereo+=np.roll(dry[:,::-1],int(delay*SR),axis=0)*gain
# DC removal and gentle high-frequency damping.
stereo=sosfilt(butter(2,50,fs=SR,btype='highpass',output='sos'),stereo,axis=0)
stereo=sosfilt(butter(2,8200,fs=SR,output='sos'),stereo,axis=0)
stereo/=max(1e-6,np.max(np.abs(stereo))/.79)
# Microfade guarantees a click-free periodic boundary without an audible long gap.
fade=int(.008*SR);stereo[:fade]*=np.linspace(0,1,fade)[:,None];stereo[-fade:]*=np.linspace(1,0,fade)[:,None]
DEST.mkdir(exist_ok=True)
with wave.open(str(DEST/'reading_garden_tar.wav'),'wb') as w:
 w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes((stereo*32767).astype('<i2').tobytes())
(DEST/'reading_garden_tar_score.json').write_text(json.dumps({'title':'A Quiet Page','duration_seconds':SECONDS,'sample_rate':SR,'description':'Original synthesized tar-inspired composition; no recording samples','notes':score},indent=2))
print(json.dumps({'duration':SECONDS,'notes':len(score),'peak':float(np.max(np.abs(stereo))),'rms':float(np.sqrt(np.mean(stereo**2))),'seam_delta':float(np.max(np.abs(stereo[0]-stereo[-1])))}))
