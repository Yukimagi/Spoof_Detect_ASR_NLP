/* dashboard.js — SafeTalk 通報後台（UI demo）
 * - 連上 ws relay（?ws=ws://...），接收 tester 送來的 {type:'report'} 事件
 * - 本機保存：localStorage（僅 demo）
 * - 左側列表＋右側詳細資訊
 */

const params = new URLSearchParams(location.search);
const WS_URL = params.get('ws') || '';
const itemsEl = document.getElementById('dashItems');
const detailEl = document.getElementById('dashDetail');
const connEl = document.getElementById('dashConn');
const searchEl = document.getElementById('dashSearch');
const filterEl = document.getElementById('dashFilter');
const riskEl = document.getElementById('dashRisk');
const clearBtn = document.getElementById('dashClear');

const STORE_KEY = 'safetalk_reports_v1';

function escapeHtml(s){
  return (s??'').toString().replace(/[&<"'>]/g, c =>
    ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#039;','"':'&quot;'}[c])
  );
}

function loadStore(){
  try { return JSON.parse(localStorage.getItem(STORE_KEY) || '[]'); }
  catch { return []; }
}
function saveStore(list){ localStorage.setItem(STORE_KEY, JSON.stringify(list)); }

let reports = loadStore();
let selectedId = null;

function riskLabel(r){
  if (r === 'high') return '高';
  if (r === 'med') return '中';
  return '低';
}
function kindLabel(k){
  if (k === 'chat') return '聊天';
  if (k === 'photo') return '照片';
  if (k === 'link') return '連結';
  if (k === 'qr') return 'QR';
  return k || '-';
}

function rowMatches(r){
  const q = (searchEl.value || '').trim().toLowerCase();
  const kind = filterEl.value;
  const risk = riskEl.value;

  if (kind !== 'all' && r.kind !== kind) return false;
  if (risk !== 'all' && r.riskLevel !== risk) return false;

  if (!q) return true;
  const hay = [
    r.id, r.userId, r.kind, r.region, r.riskLevel,
    r.summary, r.linkUrl, r.qrDecoded, r.notes
  ].join(' ').toLowerCase();
  return hay.includes(q);
}

function render(){
  const list = reports.filter(rowMatches).sort((a,b)=> (b.ts||0)-(a.ts||0));
  itemsEl.innerHTML = list.map(r=>{
    const active = (r.id === selectedId) ? ' active' : '';
    const pillCls = 'risk-pill ' + (r.riskLevel || 'low');
    return `
      <div class="dash-item${active}" data-id="${escapeHtml(r.id)}">
        <div class="dash-item-top">
          <div class="dash-item-title">${kindLabel(r.kind)} · ${escapeHtml(r.region || '未填分區')}</div>
          <div class="${pillCls}">${riskLabel(r.riskLevel)}</div>
        </div>
        <div class="dash-item-sub">
          <span class="muted">user:</span> ${escapeHtml(r.userId || '-')}&nbsp;·&nbsp;
          <span class="muted">${new Date(r.ts||Date.now()).toLocaleString()}</span>
        </div>
        <div class="dash-item-sum">${escapeHtml(r.summary || '（無摘要）')}</div>
      </div>
    `;
  }).join('') || `<div class="muted" style="padding:12px">目前沒有符合條件的通報。</div>`;

  itemsEl.querySelectorAll('.dash-item').forEach(el=>{
    el.onclick = () => {
      selectedId = el.dataset.id;
      render();
      renderDetail(reports.find(x=>x.id===selectedId));
    };
  });

  // 若沒有選中，嘗試選第一筆
  if (!selectedId && list[0]) {
    selectedId = list[0].id;
    render();
    renderDetail(list[0]);
  }
}

function renderDetail(r){
  if (!r){
    detailEl.innerHTML = `<div class="muted">點左側一筆通報即可查看。</div>`;
    return;
  }

  const blocks = [];
  blocks.push(`<div class="detail-kv"><div class="k">ID</div><div class="v">${escapeHtml(r.id)}</div></div>`);
  blocks.push(`<div class="detail-kv"><div class="k">User</div><div class="v">${escapeHtml(r.userId||'-')}</div></div>`);
  blocks.push(`<div class="detail-kv"><div class="k">分區</div><div class="v">${escapeHtml(r.region||'-')}</div></div>`);
  blocks.push(`<div class="detail-kv"><div class="k">類型</div><div class="v">${kindLabel(r.kind)}</div></div>`);
  blocks.push(`<div class="detail-kv"><div class="k">風險</div><div class="v"><span class="risk-pill ${escapeHtml(r.riskLevel||'low')}">${riskLabel(r.riskLevel)}</span></div></div>`);
  blocks.push(`<div class="detail-kv"><div class="k">時間</div><div class="v">${new Date(r.ts||Date.now()).toLocaleString()}</div></div>`);

  if (r.kind === 'link' && r.linkUrl){
    blocks.push(`<div class="detail-kv"><div class="k">URL</div><div class="v"><a href="${escapeHtml(r.linkUrl)}" target="_blank" rel="noreferrer">${escapeHtml(r.linkUrl)}</a></div></div>`);
  }
  if (r.kind === 'qr'){
    blocks.push(`<div class="detail-kv"><div class="k">QR 內容</div><div class="v">${escapeHtml(r.qrDecoded || '（未辨識）')}</div></div>`);
  }
  if (r.kind === 'photo' && r.photoDataUrl){
    blocks.push(`<div class="detail-img-wrap"><img class="detail-img" src="${escapeHtml(r.photoDataUrl)}" alt="photo"></div>`);
  }

  if (r.chatSnapshot && Array.isArray(r.chatSnapshot)){
    const last = r.chatSnapshot.slice(-6).map(m=>`<div class="snap ${m.from==='tester'?'me':''}">${escapeHtml(m.raw || m.text || '')}</div>`).join('');
    blocks.push(`<div class="detail-section-title">最近對話（截取最後 6 則）</div><div class="snap-wrap">${last}</div>`);
  }

  if (r.notes){
    blocks.push(`<div class="detail-section-title">備註</div><div class="detail-notes">${escapeHtml(r.notes)}</div>`);
  }

  detailEl.innerHTML = blocks.join('');
}

function addReport(r){
  reports.push(r);
  // 限制最大筆數（demo 用）
  if (reports.length > 300) reports = reports.slice(-300);
  saveStore(reports);
  render();
}

// --- WebSocket ---
let ws = null;
function setConn(ok){
  connEl.textContent = ok ? '已連線' : '未連線';
  connEl.className = 'dash-pill ' + (ok ? 'ok' : 'bad');
}

function connect(){
  if(!WS_URL){
    setConn(false);
    connEl.textContent = '未指定 ws=';
    return;
  }
  ws = new WebSocket(WS_URL);
  ws.onopen = ()=> setConn(true);
  ws.onclose = ()=> setConn(false);
  ws.onerror = ()=> setConn(false);
  ws.onmessage = (e)=>{
    let m=null;
    try{ m = JSON.parse(e.data); }catch(_){ return; }
    if (m && m.type === 'report') addReport(m.payload);
  };
}
connect();

searchEl.oninput = render;
filterEl.onchange = render;
riskEl.onchange = render;

clearBtn.onclick = ()=>{
  if (!confirm('確定要清空本機列表？（不會影響其他人）')) return;
  reports = [];
  selectedId = null;
  saveStore(reports);
  render();
};

render();
