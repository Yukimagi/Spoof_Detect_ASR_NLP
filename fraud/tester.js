/* tester.js — SafeTalk (測試者端)
 * 功能：
 *  - 與 scammer.html 雙向同步（BroadcastChannel / WebSocket ?ws=）
 *  - 去識別化（彩色膠囊標示）/ 還原
 *  - 風險分析（強指標＋次強關鍵字）
 *  - 可拖曳監控外掛＋可縮成小 icon（🛡️）
 *  - 分區通報（110/165/新竹東/北/香山）＋「問題已解決」避免重複派案
 */

// ---------- 連線層（BroadcastChannel / WebSocket） ----------
const params = new URLSearchParams(location.search);
const WS_URL = params.get('ws');
let bc = null, ws = null;

function tx(msg) {
  const payload = JSON.stringify(msg);
  if (ws && ws.readyState === 1) ws.send(payload);
  if (bc) bc.postMessage(msg);
}

(function initTransport(){
  if (WS_URL) {
    // ✅ 有指定 ws= 就只用 WebSocket，避免一條訊息走兩次
    ws = new WebSocket(WS_URL);
    ws.onmessage = (e)=> onIncoming(JSON.parse(e.data));
    ws.onerror  = ()=> console.warn('WebSocket error');
    return;
  }

  // ✅ 沒 ws 參數時，才使用 BroadcastChannel 在同一台電腦測試
  try {
    bc = new BroadcastChannel('fraud-sim');
    bc.onmessage = (ev)=> onIncoming(ev.data);
  } catch (_) {}
})();


// ---------- UI 元素 ----------
const chatArea  = document.getElementById('chatArea');
const chatInput = document.getElementById('chatInput');
const sendBtn   = document.getElementById('sendBtn');

const plugin      = document.getElementById('plugin');
const handle      = document.getElementById('pluginHandle');
const badge       = document.getElementById('pluginBadge');
const analyzeBtn  = document.getElementById('pluginAnalyze');
const redactBtn   = document.getElementById('pluginRedact');
const restoreBtn  = document.getElementById('pluginRestore');
const statusEl    = document.getElementById('pluginStatus');
const fillEl      = document.getElementById('pluginFill');
const logsEl      = document.getElementById('pluginLogs');
const regionSel   = document.getElementById('regionSelect');
const toggleBtn   = document.getElementById('pluginToggle');
const pluginFab   = document.getElementById('pluginFab'); // 🛡️ 縮小後的小圓鈕

// 緊急聯絡人設定（本機保存，不上傳）
const ecOverlay   = document.getElementById('ecOverlay');
const openEC      = document.getElementById('openEC');
const ecName      = document.getElementById('ecName');
const ecPhone     = document.getElementById('ecPhone');
const ecRegion    = document.getElementById('ecRegion');
const ecAdd       = document.getElementById('ecAdd');
const ecList      = document.getElementById('ecList');
const ecPreset    = document.getElementById('ecPreset');
const ecSave      = document.getElementById('ecSave');
const ecSkip      = document.getElementById('ecSkip');
const ecAutoNotify= document.getElementById('ecAutoNotify');

const eduOverlay = document.getElementById('eduOverlay');
const eduClose   = document.getElementById('eduClose');
const eduImg     = document.getElementById('eduImg'); // 現在用不到，但保留未來換圖/影片可用


// ---------- 對話狀態 ----------
/* 保留 raw（原文）與 text（展示）。去識別化只改 text；還原把 text=raw。*/
let messages = [
  {from:'scammer', raw:'您好，我們是客服，提供高報酬投資方案。', text:'您好，我們是客服，提供高報酬投資方案。', time:'3:28'},
  {from:'tester',  raw:'請先說明方案與風險。',                         text:'請先說明方案與風險。',                         time:'3:30'}
];

// 旗標：案件是否已標記「問題已解決」（避免重複派案）
let CASE_RESOLVED = false;

// ---------- 小工具 ----------
function escapeHtml(s){
  return (s||'').toString().replace(/[&<"'>]/g, c =>
    ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#039;','"':'&quot;'}[c])
  );
}
function maskToHTML(strEscaped){
  return strEscaped
    .replace(/\[CARD\]/g,'<span class="mask">CARD</span>')
    .replace(/\[ID\]/g,'<span class="mask">ID</span>')
    .replace(/\[PHONE\]/g,'<span class="mask">PHONE</span>')
    .replace(/\[CODE\]/g,'<span class="mask">CODE</span>')
    .replace(/\[LINK\]/g,'<span class="mask">LINK</span>');
}

// ---------- 渲染 ----------
function render(){
  chatArea.innerHTML = '';
  messages.forEach(m=>{
    // 在 tester 端：tester 在右（綠色），scammer 在左（白色）
    const row = document.createElement('div');
    row.className = 'msg-row' + (m.from === 'tester' ? ' right' : '');
    const av = document.createElement('div');
    av.className  = 'avatar';
    av.innerHTML  = '<img src="avatar1.png">';
    const bubble = document.createElement('div');
    bubble.className = 'bubble';

    const html = maskToHTML(escapeHtml(m.text));
    bubble.innerHTML = `
      <div class="txt">${html}</div>
      <div class="meta"><span class="time">${m.time||''}</span></div>
    `;
    if (m.text !== m.raw) bubble.classList.add('sensitive');

    row.appendChild(av);
    row.appendChild(bubble);
    chatArea.appendChild(row);
  });
  chatArea.scrollTop = chatArea.scrollHeight;
}
render();

// 發送訊息
sendBtn.addEventListener('click', ()=>{
  const v = chatInput.value.trim();
  if (!v) return;
  const msg = {type:'chat', from:'tester', raw:v, text:v, time:new Date().toLocaleTimeString()};
  messages.push(msg);
  render();
  chatInput.value = '';
  tx(msg);
});

// 收到遠端訊息 / 指令（只處理 chat、redact、restore）
function onIncoming(m){
  if (m.type === 'chat'){
    messages.push(m);
    render();
  } else if (m.type === 'redact'){
    applyRedact(true);
  } else if (m.type === 'restore'){
    applyRedact(false);
  }
}

// ===== 監控外掛：拖曳 / 縮小成 icon =====
toggleBtn.addEventListener('click', minimizePlugin);
pluginFab.addEventListener('click', restorePlugin);

/* ===================== 🛡️ 小圓鈕可拖曳 ===================== */
// 位置記憶（可選）：關掉再開一樣在原地
const FAB_POS_KEY = 'fm_fab_pos_v1';

// 啟動時還原上次位置
(function initFabPos(){
  const vw = window.innerWidth;
  const vh = window.innerHeight;

  try{
    const pos = JSON.parse(localStorage.getItem(FAB_POS_KEY) || 'null');

    // 👉 小螢幕（手機 / 窄視窗）：一律用預設位置，不吃桌機的 left/top
    if (vw < 700 || !pos) {
      pluginFab.style.left   = '';
      pluginFab.style.top    = '';
      pluginFab.style.right  = '16px';
      // 往上搬一點，避免蓋住輸入框，看起來在聊天室內部
      pluginFab.style.bottom = (vw < 700 ? '90px' : '24px');
      return;
    }

    // 👉 桌機：只有座標還在畫面內才套用，超出就用預設位置
    if (typeof pos.left === 'number' && typeof pos.top === 'number') {
      const maxX = vw - 60;
      const maxY = vh - 60;
      const left = Math.min(Math.max(8, pos.left), maxX);
      const top  = Math.min(Math.max(8, pos.top),  maxY);
      pluginFab.style.left   = left + 'px';
      pluginFab.style.top    = top  + 'px';
      pluginFab.style.right  = 'auto';
      pluginFab.style.bottom = 'auto';
    }
  } catch(e){
    // 解析失敗時就用預設
    pluginFab.style.left   = '';
    pluginFab.style.top    = '';
    pluginFab.style.right  = '16px';
    pluginFab.style.bottom = (window.innerWidth < 700 ? '90px' : '24px');
  }
})();


let fabDrag=false, fabStartX=0, fabStartY=0, fabOrigX=0, fabOrigY=0, fabMoved=false;

pluginFab.addEventListener('pointerdown', (e)=>{
  // 進入拖曳模式
  fabDrag   = true;
  fabMoved  = false;
  fabStartX = e.clientX;
  fabStartY = e.clientY;

  // 轉用 left/top 布局，避免 right/bottom 讓位置反向
  const r = pluginFab.getBoundingClientRect();
  pluginFab.style.left   = r.left + 'px';
  pluginFab.style.top    = r.top  + 'px';
  pluginFab.style.right  = 'auto';
  pluginFab.style.bottom = 'auto';

  fabOrigX = parseFloat(pluginFab.style.left) || r.left;
  fabOrigY = parseFloat(pluginFab.style.top)  || r.top;

  pluginFab.classList.add('dragging');

  // 阻止文字選取、避免觸發點擊還原
  e.preventDefault();
  try{ pluginFab.setPointerCapture(e.pointerId); }catch(_){}
});

window.addEventListener('pointermove', (e)=>{
  if(!fabDrag) return;
  const dx = e.clientX - fabStartX;
  const dy = e.clientY - fabStartY;
  if(Math.abs(dx) > 4 || Math.abs(dy) > 4) fabMoved = true;

  const vw = innerWidth, vh = innerHeight;
  const w  = pluginFab.offsetWidth, h = pluginFab.offsetHeight;

  // 邊界限制
  let nx = Math.min(Math.max(8, fabOrigX + dx), vw - w - 8);
  let ny = Math.min(Math.max(8, fabOrigY + dy), vh - h - 8);

  pluginFab.style.left = nx + 'px';
  pluginFab.style.top  = ny + 'px';
});

window.addEventListener('pointerup', (e)=>{
  if(!fabDrag) return;
  fabDrag = false;
  pluginFab.classList.remove('dragging');
  try{ pluginFab.releasePointerCapture(e.pointerId); }catch(_){}

  // 有移動：存位置；沒移動：當成「點擊」→ 展開外掛
  if (fabMoved) {
    try{
      // 只在寬螢幕的情況下記錄位置，避免桌機座標害手機跑出畫面
      if (window.innerWidth >= 700) {
        const r = pluginFab.getBoundingClientRect();
        localStorage.setItem(FAB_POS_KEY, JSON.stringify({left: r.left, top: r.top}));
      }
    }catch(_){}
  } else {
    // 沒移動就當作點擊 → 展開外掛
    restorePlugin();
  }

});
/* ========================================================== */


// 讓縮小鈕不觸發手把的 pointerdown（避免被當成拖曳）
toggleBtn.addEventListener('pointerdown', (e)=> {
  e.stopPropagation();
});

let dragging=false, sx=0, sy=0, ox=0, oy=0;
handle.addEventListener('pointerdown', (e)=>{
  // 如果點到的是縮小鈕，就不要啟動拖曳
  if (e.target.closest('#pluginToggle')) return;

  dragging=true; sx=e.clientX; sy=e.clientY;
  const r=plugin.getBoundingClientRect();
  ox = plugin.style.left ? parseFloat(plugin.style.left) : r.left;
  oy = plugin.style.top  ? parseFloat(plugin.style.top)  : r.top;
  plugin.style.right='auto'; plugin.style.bottom='auto';
  try{ plugin.setPointerCapture(e.pointerId); }catch(_){}
});
window.addEventListener('pointermove', (e)=>{
  if(!dragging) return;
  const dx=e.clientX-sx, dy=e.clientY-sy;
  const vw=innerWidth, vh=innerHeight, w=plugin.offsetWidth, h=plugin.offsetHeight;
  const nx=Math.min(Math.max(8, ox+dx), vw-w-8);
  const ny=Math.min(Math.max(8, oy+dy), vh-h-8);
  plugin.style.left=nx+'px';
  plugin.style.top =ny+'px';
});
window.addEventListener('pointerup', (e)=>{
  dragging=false;
  try{ plugin.releasePointerCapture(e.pointerId); }catch(_){}
});

// 縮到小圓鈕（保底確保看得到 icon）
function minimizePlugin(){
  plugin.style.display = 'none';
  pluginFab.style.display = 'flex';
  // 保底：若仍看不到，移除可能殘留的 inline 與 class 影響
  if (getComputedStyle(pluginFab).display === 'none') {
    pluginFab.style.removeProperty('display');
    pluginFab.classList.remove('hidden');
  }
}

// 從小圓鈕還原
function restorePlugin(){
  plugin.style.display = '';
  pluginFab.style.display = 'none';
}

// 鍵盤保底：按 Esc 直接還原外掛
window.addEventListener('keydown', (e)=>{
  if (e.key === 'Escape') restorePlugin();
});


// ---------- 去識別化 / 還原 ----------
function redactOnce(s){
  return s
    // 卡號：關鍵字 + 任意 6+ 位數（含空白/破折號），或連續 12+ 位數字
    .replace(/卡[號号]\s*[:：]?\s*([0-9][0-9 -]{5,})/g, '卡號 [CARD]')
    .replace(/\b(?:\d[ -]?){12,}\b/g, '[CARD]')
    // 身分證：標準格式 或 關鍵字 + 6+ 位數
    .replace(/\b[A-Z][12]\d{8}\b/g, '[ID]')
    .replace(/身分證\s*[:：]?\s*\d{6,}/g, '身分證 [ID]')
    // 手機：09xxxxxxxx，允許破折號
    .replace(/\b0?9\d{2}[- ]?\d{3}[- ]?\d{3}\b/g, '[PHONE]')
    // 驗證碼：關鍵字後或獨立 6~8 位
    .replace(/驗證碼[^0-9]*\d{4,8}/g, '驗證碼 [CODE]')
    .replace(/(?<!\d)\d{6,8}(?!\d)/g, '[CODE]')
    // 連結
    .replace(/https?:\/\/\S+/g, '[LINK]');
}
function applyRedact(on){
  messages = messages.map(m => on
    ? ({...m, text: redactOnce(m.raw)})
    : ({...m, text: m.raw})
  );
  render();
}
redactBtn.addEventListener('click', ()=>{
  applyRedact(true);
  tx({type:'redact'});   // 同步指令（詐騙端會忽略，但保留一致性）
  logsEl.textContent='已去識別化';
});
restoreBtn.addEventListener('click', ()=>{
  applyRedact(false);
  tx({type:'restore'});
  logsEl.textContent='已還原';
});

// ---------- 風險分析 & 分區通報 ----------
const PRESET_UNITS = [
  {name:'110(警察)',      phone:'110',        region:'全國'},
  {name:'165(反詐騙)',    phone:'165',        region:'全國'},
  {name:'新竹市東區社福',  phone:'(03)5710523', region:'東區'},
  {name:'新竹市北區社福',  phone:'(03)5232055', region:'北區'},
  {name:'新竹市香山區社福',phone:'(03)5181309', region:'香山區'}
];
function regionContacts(region){
  return PRESET_UNITS.filter(u => u.region==='全國' || u.region===region);
}

// 強/中指標
const STRONG_INDICATORS = [
  (t)=> /\b(?:\d[ -]?){13,19}\b/.test(t) || (/卡[號号]/.test(t) && /\d{6,}/.test(t)), // 卡號
  (t)=> /\b0?9\d{8}\b/.test(t),                                                     // 手機
  (t)=> /\b[A-Z][12]\d{8}\b/.test(t) || /身分證\s*[:：]?\s*\d{6,}/.test(t),            // 身分證
  (t)=> /(?<!\d)\d{6}(?!\d)/.test(t) || /驗證碼/.test(t),                            // 驗證碼
  (t)=> /https?:\/\//.test(t) && /(支付|繳費|登入|投資|銀行|匯款|提款)/.test(t)          // 可疑連結+金流詞
];
const MEDIUM_KEYWORDS = ['支付','運費','抽中','帳號','匯款','提款','銀行','上傳','護照','投資','翻倍','卡號','身分證'];

function computeRiskScore(list){
  let score = 0, strongHits = 0;
  list.forEach(m=>{
    const t = (m.raw||m.text||'');
    STRONG_INDICATORS.forEach(fn => { if(fn(t)){ strongHits++; score += 30; } });
    MEDIUM_KEYWORDS.forEach(k => { if(t.includes(k)) score += 12; }); // 放大權重
  });
  // 正規化（訊息很多時扣一些，避免被沖淡）
  score = Math.min(100, score - Math.max(0, (list.length-6))*4);
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

let toast=null;
function showToast(html){
  if(toast) toast.remove();
  toast = document.createElement('div');
  toast.className = 'toast';
  toast.innerHTML = html;
  document.body.appendChild(toast);
}
function hideToast(){ if(toast){ toast.remove(); toast=null; } }

function showEduOverlay(){
  eduOverlay.style.display = 'flex';
  eduOverlay.setAttribute('aria-hidden', 'false');
}

function hideEduOverlay(){
  eduOverlay.style.display = 'none';
  eduOverlay.setAttribute('aria-hidden', 'true');
}

// 點背景區域也可以關閉
eduOverlay.addEventListener('click', (e)=>{
  if (e.target === eduOverlay) hideEduOverlay();
});
eduClose.addEventListener('click', hideEduOverlay);


function animateAnalyze(cb){
  fillEl.style.width='0%'; logsEl.textContent='分析中…';
  let p=0; const iv=setInterval(()=>{
    p += Math.random()*20+5;
    if (p>100) p=100;
    fillEl.style.width = p+'%';
    if (p===100){ clearInterval(iv); cb(); }
  }, 300);
}

analyzeBtn.addEventListener('click', ()=>{
  animateAnalyze(()=>{
    const result = computeRiskScore(messages);
    showBadge(result);

    if (CASE_RESOLVED){
      logsEl.textContent = '案件已標記為「已解決」，未觸發通報。';
      hideToast();
      return;
    }

    if (result.level === 'high'){
      showEduOverlay(); // ★ 新增：高風險同時跳出防詐宣導圖片
      const region = regionSel.value || '全國';
      const list = regionContacts(region);
      showToast(`<div>偵測到 <b>高風險</b>。是否通知 <b>${region}</b> 名單 與緊急聯絡人？</div>
        <div style="margin-top:6px">${list.map(i=>`• ${i.name}（${i.phone}）`).join('<br>')}</div>
        <div class="actions">
          <button class="go">一鍵通知</button>
          <button class="resolved">問題已解決，請其他單位略過</button>
          <button class="cancel">取消</button>
        </div>`);
      toast.querySelector('.cancel').onclick = hideToast;
      toast.querySelector('.go').onclick = ()=>{
        logsEl.textContent='已送出通知至：'+list.map(i=>i.name).join('、')+' 與緊急聯絡人';
        hideToast();
      };
      toast.querySelector('.resolved').onclick = ()=>{
        CASE_RESOLVED = true;
        logsEl.textContent='已標記：問題已解決，後續單位可略過（避免重複派案）';
        hideToast();
      };
    } 
    else if (result.level === 'med'){
      showEduOverlay(); // ★ 新增：中風險同時跳出防詐宣導圖片
      const region = regionSel.value || '全國';
      const list = regionContacts(region);
      showToast(`<div>偵測到 <b>中風險</b>。是否通知緊急聯絡人？</div>
        <div class="actions">
          <button class="go">一鍵通知</button>
          <button class="cancel">取消</button>
        </div>`);
      toast.querySelector('.cancel').onclick = hideToast;
      toast.querySelector('.go').onclick = ()=>{
        logsEl.textContent='已送出通知至：'+' 緊急聯絡人';
        hideToast();
      };
    } else {
      hideToast();
      logsEl.textContent='已完成分析。';
    }
  });
});

// ---------- 緊急聯絡人：本機保存 ----------
const EC_KEY='fm_ec_v4';
function loadEC(){
  try{ return JSON.parse(localStorage.getItem(EC_KEY)||'{"list":[],"auto":true}'); }
  catch(_){ return {list:[],auto:true}; }
}
function saveEC(obj){ localStorage.setItem(EC_KEY, JSON.stringify(obj)); }
function renderEC(){
  const d = loadEC();
  ecList.innerHTML = d.list.map((c,i)=>`
    <li class="ec-item">
      <div class="info"><strong>${escapeHtml(c.name||'(單位)')}</strong>
        <span>${escapeHtml(c.phone)} · ${escapeHtml(c.region||'全國')}</span></div>
      <button class="del" data-i="${i}">刪除</button>
    </li>`).join('') || '<li class="ec-item"><div class="info">尚無聯絡人</div></li>';
  ecList.querySelectorAll('.del').forEach(btn=>{
    btn.onclick=()=>{ const d2=loadEC(); d2.list.splice(+btn.dataset.i,1); saveEC(d2); renderEC(); };
  });
}
document.getElementById('openEC').onclick=()=>{
  const d=loadEC(); ecAutoNotify.checked=d.auto; renderEC();
  ecOverlay.style.display='flex'; ecOverlay.setAttribute('aria-hidden','false');
};
ecAdd.onclick=()=>{
  const d=loadEC();
  d.list.push({name:ecName.value.trim(), phone:ecPhone.value.trim(), region:(ecRegion.value.trim()||'全國')});
  saveEC(d); ecName.value=''; ecPhone.value=''; ecRegion.value=''; renderEC();
};
ecPreset.onclick=()=>{
  const d=loadEC();
  const preset = [
    {name:'110(警察)',      phone:'110',        region:'全國'},
    {name:'165(反詐騙)',    phone:'165',        region:'全國'},
    {name:'新竹市東區社福',  phone:'(03)5710523', region:'東區'},
    {name:'新竹市北區社福',  phone:'(03)5232055', region:'北區'},
    {name:'新竹市香山區社福',phone:'(03)5181309', region:'香山區'}
  ];
  preset.forEach(u=>{ if(!d.list.some(x=>x.phone===u.phone)) d.list.push(u); });
  saveEC(d); renderEC();
};
ecSave.onclick=()=>{
  const d=loadEC(); d.auto=!!ecAutoNotify.checked; saveEC(d);
  ecOverlay.style.display='none'; ecOverlay.setAttribute('aria-hidden','true');
};
ecSkip.onclick=()=>{
  ecOverlay.style.display='none'; ecOverlay.setAttribute('aria-hidden','true');
};
