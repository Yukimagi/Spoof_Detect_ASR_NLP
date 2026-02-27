// ---- transport: BroadcastChannel or WebSocket (?ws=) ----
const params = new URLSearchParams(location.search);
const WS_URL = params.get('ws');
let bc = null, ws = null;

function tx(msg){
  const payload = JSON.stringify(msg);
  if(ws && ws.readyState === 1) ws.send(payload);
  if(bc) bc.postMessage(msg);
}
(function initTransport(){
  if(WS_URL){
    ws = new WebSocket(WS_URL);
    ws.onmessage = (e)=> onIncoming(JSON.parse(e.data));
  }
  try{
    bc = new BroadcastChannel('fraud-sim');
    bc.onmessage = (ev)=> onIncoming(ev.data);
  }catch(_) {}
})();

// ---- chat ----
const chatArea = document.getElementById('chatArea');
const chatInput = document.getElementById('chatInput');
const sendBtn   = document.getElementById('sendBtn');

// 重要：訊息同時保存 raw（原文）與 text（展示用）。還原/去識別化只改 text。
let messages = [
  {from:'scammer', raw:'您好，我們是客服，提供高報酬投資方案。', text:'您好，我們是客服，提供高報酬投資方案。', time:'3:28'},
  {from:'tester',  raw:'請先說明方案與風險。',                         text:'請先說明方案與風險。',                         time:'3:30'}
];

function escapeHtml(s){return (s||'').toString().replace(/[&<"'>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#039;','"':'&quot;'})[c])}
function maskToHTML(strEscaped){
  return strEscaped
    .replace(/\[CARD\]/g,'<span class="mask">CARD</span>')
    .replace(/\[ID\]/g,'<span class="mask">ID</span>')
    .replace(/\[PHONE\]/g,'<span class="mask">PHONE</span>')
    .replace(/\[CODE\]/g,'<span class="mask">CODE</span>')
    .replace(/\[LINK\]/g,'<span class="mask">LINK</span>');
}
function render(){
  chatArea.innerHTML='';
  messages.forEach(m=>{
    const row=document.createElement('div'); row.className='msg-row'+(m.from==='tester'?' right':'');
    const av=document.createElement('div'); av.className='avatar'; av.innerHTML='<img src="avatar1.png">';
    const bubble=document.createElement('div'); bubble.className='bubble';

    const rawEsc = escapeHtml(m.text); // m.text 可能已被替換為 [CARD] 等
    const html   = maskToHTML(rawEsc);

    bubble.innerHTML = `<div class="txt">${html}</div><div class="meta"><span class="time">${m.time||''}</span></div>`;
    if(m.text!==m.raw) bubble.classList.add('sensitive');
    row.appendChild(av); row.appendChild(bubble);
    chatArea.appendChild(row);
  });
  chatArea.scrollTop = chatArea.scrollHeight;
}

render();

sendBtn.addEventListener('click', ()=>{
  const v = chatInput.value.trim(); if(!v) return;
  const msg = {type:'chat', from:'tester', raw:v, text:v, time:new Date().toLocaleTimeString()};
  messages.push(msg); render(); chatInput.value='';
  tx(msg);
});

function onIncoming(m){
  if(m.type==='chat'){ messages.push(m); render(); }
  if(m.type==='redact'){ applyRedact(true); }
  if(m.type==='restore'){ applyRedact(false); }
}

// ---- 監控外掛（分析 + 去識別化 + 分區通知）----
const plugin   = document.getElementById('plugin');
const handle   = document.getElementById('pluginHandle');
const badge    = document.getElementById('pluginBadge');
const analyzeBtn = document.getElementById('pluginAnalyze');
const redactBtn  = document.getElementById('pluginRedact');
const restoreBtn = document.getElementById('pluginRestore');
const statusEl   = document.getElementById('pluginStatus');
const fillEl     = document.getElementById('pluginFill');
const logsEl     = document.getElementById('pluginLogs');
const regionSel  = document.getElementById('regionSelect');
const toggleBtn  = document.getElementById('pluginToggle');

toggleBtn.addEventListener('click', ()=> plugin.classList.toggle('collapsed'));

// 可拖曳 + 邊界限制
let dragging=false,sx=0,sy=0,ox=0,oy=0;
handle.addEventListener('pointerdown', (e)=>{
  dragging=true; sx=e.clientX; sy=e.clientY;
  const r=plugin.getBoundingClientRect();
  ox=plugin.style.left?parseFloat(plugin.style.left):r.left;
  oy=plugin.style.top?parseFloat(plugin.style.top):r.top;
  plugin.style.right='auto'; plugin.style.bottom='auto';
  try{ plugin.setPointerCapture(e.pointerId); }catch(_){}
});
window.addEventListener('pointermove', (e)=>{
  if(!dragging) return;
  const dx=e.clientX-sx, dy=e.clientY-sy;
  const vw=innerWidth, vh=innerHeight, w=plugin.offsetWidth, h=plugin.offsetHeight;
  const nx=Math.min(Math.max(8, ox+dx), vw-w-8);
  const ny=Math.min(Math.max(8, oy+dy), vh-h-8);
  plugin.style.left=nx+'px'; plugin.style.top=ny+'px';
});
window.addEventListener('pointerup', (e)=>{ dragging=false; try{ plugin.releasePointerCapture(e.pointerId);}catch(_){}});

// === 去識別化（修正版）===
function redactOnce(s){
  return s
    // 1) 卡號：關鍵字 + 任意 6+ 位數字（容許空白/破折號），或連續 12+ 位數字
    .replace(/卡[號号]\s*[:：]?\s*([0-9][0-9 -]{5,})/g, '卡號 [CARD]')
    .replace(/\b(?:\d[ -]?){12,}\b/g, '[CARD]')

    // 2) 身分證：標準格式，或遇到關鍵字 + 6+ 位數字
    .replace(/\b[A-Z][12]\d{8}\b/g, '[ID]')
    .replace(/身分證\s*[:：]?\s*\d{6,}/g, '身分證 [ID]')

    // 3) 手機：09xxxxxxxx，允許破折號
    .replace(/\b0?9\d{2}[- ]?\d{3}[- ]?\d{3}\b/g, '[PHONE]')

    // 4) 驗證碼：關鍵字後面或**任何**獨立 6~8 位數字
    .replace(/驗證碼[^0-9]*\d{4,8}/g, '驗證碼 [CODE]')
    .replace(/(?<!\d)\d{6,8}(?!\d)/g, '[CODE]')

    // 5) 連結
    .replace(/https?:\/\/\S+/g, '[LINK]');
}
function applyRedact(on){
  messages = messages.map(m => {
    if(on) return {...m, text: redactOnce(m.raw)};
    else   return {...m, text: m.raw};
  });
  render();
}
redactBtn.addEventListener('click', ()=>{ applyRedact(true); tx({type:'redact'}); logsEl.textContent='已去識別化'; });
restoreBtn.addEventListener('click', ()=>{ applyRedact(false); tx({type:'restore'}); logsEl.textContent='已還原'; });

// === 分析（強化版風險評分）===
const STRONG_INDICATORS = [
  (t)=> /\b(?:\d[ -]?){13,19}\b/.test(t) || (/卡[號号]/.test(t) && /\d{6,}/.test(t)),                 // 卡號
  (t)=> /\b0?9\d{8}\b/.test(t),                                                                        // 手機
  (t)=> /\b[A-Z][12]\d{8}\b/.test(t) || /身分證\s*[:：]?\s*\d{6,}/.test(t),                              // 身分證
  (t)=> /(?<!\d)\d{6}(?!\d)/.test(t) || /驗證碼/.test(t),                                                // 驗證碼/六位數
  (t)=> /https?:\/\//.test(t) && /(支付|繳費|登入|投資|銀行|匯款|提款)/.test(t)                          // 可疑連結+金流詞
];
const MEDIUM_KEYWORDS = ['支付','運費','抽中','帳號','匯款','提款','銀行','上傳','護照','投資','翻倍','卡號','身分證'];

function computeRiskScore(list){
  let score = 0;
  let strongHits = 0;
  list.forEach(m=>{
    const t = (m.raw||m.text||'');
    // 強指標：每命中一個 +30
    STRONG_INDICATORS.forEach(fn => { if(fn(t)) { strongHits++; score += 30; } });
    // 次強：每命中一個 +8
    MEDIUM_KEYWORDS.forEach(k => { if(t.includes(k)) score += 8; });
  });
  // 正規化：避免訊息太多被沖淡
  score = Math.min(100, score - Math.max(0, (list.length-6))*4);
  // 直接提升層級：若強指標 >=2，視作高風險
  const level = (strongHits >= 2 || score >= 70) ? 'high' : (score >= 35 ? 'med' : 'low');
  return {score, level, strongHits};
}

function showBadge(r){
  const {score, level} = r;
  const text = level==='high' ? '高風險' : level==='med' ? '中風險' : '低風險';
  badge.className = 'badge ' + level;
  badge.textContent = level.toUpperCase();
  statusEl.textContent = `${text}（分數 ${Math.round(score)}%）`;
}

function animateAnalyze(cb){
  fillEl.style.width='0%'; logsEl.textContent='分析中…';
  let p=0; const iv=setInterval(()=>{ p+=Math.random()*20+5; if(p>100)p=100; fillEl.style.width=p+'%'; if(p===100){clearInterval(iv); cb();}},300);
}

const PRESET_UNITS = [
  {name:'110(警察)', phone:'110', region:'全國'},
  {name:'165(反詐騙)', phone:'165', region:'全國'},
  {name:'新竹市東區社福', phone:'(03)5710523', region:'東區'},
  {name:'新竹市北區社福', phone:'(03)5232055', region:'北區'},
  {name:'新竹市香山區社福', phone:'(03)5181309', region:'香山區'}
];

let toast=null;
function regionContacts(region){
  return PRESET_UNITS.filter(u => u.region==='全國' || u.region===region);
}
function showToast(html){
  if(toast){ toast.remove(); }
  toast=document.createElement('div'); toast.className='toast'; toast.innerHTML=html; document.body.appendChild(toast);
}
function hideToast(){ if(toast){ toast.remove(); toast=null; } }

document.getElementById('pluginAnalyze').addEventListener('click', ()=>{
  animateAnalyze(()=>{
    const result = computeRiskScore(messages);
    showBadge(result);

    if(result.level==='high'){
      const region = regionSel.value || '全國';
      const list = regionContacts(region);
      showToast(`<div>偵測到 <b>高風險</b>。是否通知 <b>${region}</b> 名單 與 緊急聯絡人？</div>
        <div style="margin-top:6px">${list.map(i=>`• ${i.name}（${i.phone}）`).join('<br>')}</div>
        <div class="actions"><button class="go">一鍵通知</button><button class="cancel">取消</button></div>`);
      toast.querySelector('.cancel').onclick=hideToast;
      toast.querySelector('.go').onclick=()=>{
        logsEl.textContent='已送出通知至：'+list.map(i=>i.name).join('、')+"與緊急聯絡人";
        hideToast();
      };
    }else{
      hideToast();
      logsEl.textContent='已完成分析。';
    }
  });
});

// ---- EC modal（本機） ----
const openEC=document.getElementById('openEC');
const ecOverlay=document.getElementById('ecOverlay');
const ecName=document.getElementById('ecName');
const ecPhone=document.getElementById('ecPhone');
const ecRegion=document.getElementById('ecRegion');
const ecAdd=document.getElementById('ecAdd');
const ecList=document.getElementById('ecList');
const ecPreset=document.getElementById('ecPreset');
const ecSave=document.getElementById('ecSave');
const ecSkip=document.getElementById('ecSkip');
const ecAutoNotify=document.getElementById('ecAutoNotify');

const EC_KEY='fm_ec_v4';
function loadEC(){ try{ return JSON.parse(localStorage.getItem(EC_KEY)||'{"list":[],"auto":true}'); }catch(_){ return {list:[],auto:true}; } }
function saveEC(obj){ localStorage.setItem(EC_KEY, JSON.stringify(obj)); }
function renderEC(){
  const d=loadEC();
  ecList.innerHTML = d.list.map((c,i)=>`<li class="ec-item"><div class="info"><strong>${escapeHtml(c.name||'(單位)')}</strong><span>${escapeHtml(c.phone)} · ${escapeHtml(c.region||'全國')}</span></div><button class="del" data-i="${i}">刪除</button></li>`).join('') || '<li class="ec-item"><div class="info">尚無聯絡人</div></li>';
  ecList.querySelectorAll('.del').forEach(btn=>{
    btn.onclick=()=>{ const d2=loadEC(); d2.list.splice(+btn.dataset.i,1); saveEC(d2); renderEC(); };
  });
}
document.getElementById('openEC').onclick=()=>{ const d=loadEC(); ecAutoNotify.checked=d.auto; renderEC(); ecOverlay.style.display='flex'; ecOverlay.setAttribute('aria-hidden','false'); };
ecAdd.onclick=()=>{ const d=loadEC(); d.list.push({name:ecName.value.trim(), phone:ecPhone.value.trim(), region:(ecRegion.value.trim()||'全國')}); saveEC(d); ecName.value=''; ecPhone.value=''; ecRegion.value=''; renderEC(); };
ecPreset.onclick=()=>{ const d=loadEC(); PRESET_UNITS.forEach(u=>{ if(!d.list.some(x=>x.phone===u.phone)) d.list.push(u); }); saveEC(d); renderEC(); };
ecSave.onclick=()=>{ const d=loadEC(); d.auto=!!ecAutoNotify.checked; saveEC(d); ecOverlay.style.display='none'; ecOverlay.setAttribute('aria-hidden','true'); };
ecSkip.onclick=()=>{ ecOverlay.style.display='none'; ecOverlay.setAttribute('aria-hidden','true'); };
