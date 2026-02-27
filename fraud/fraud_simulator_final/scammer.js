// scammer.js — 綠色=詐騙者、白色=測試者；不做遮罩
const params = new URLSearchParams(location.search);
const WS_URL = params.get('ws');
let bc = null, ws = null;

function tx(msg){
  const payload = JSON.stringify(msg);
  if (ws && ws.readyState === 1) ws.send(payload);
  if (bc) bc.postMessage(msg);
}
(function initTransport(){
  if (WS_URL) {
    ws = new WebSocket(WS_URL);
    ws.onmessage = (e) => onIncoming(JSON.parse(e.data));
  }
  try {
    bc = new BroadcastChannel('fraud-sim');
    bc.onmessage = (ev) => onIncoming(ev.data);
  } catch (_) {}
})();

const chatArea  = document.getElementById('chatArea');
const chatInput = document.getElementById('chatInput');
const sendBtn   = document.getElementById('sendBtn');

// 詐騙端不做遮罩，僅保存 text
let messages = [
  {from:'scammer', text:'您好，我們是客服，提供高報酬投資方案。', time:'3:28'},
  {from:'tester',  text:'請先說明方案與風險。',                         time:'3:30'}
];

function escapeHtml(s){
  return (s||'').toString().replace(/[&<"'>]/g, c =>
    ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#039;','"':'&quot;'}[c])
  );
}

function render(){
  chatArea.innerHTML = '';
  messages.forEach(m => {
    // 這裡改成：詐騙者 on the RIGHT（綠色氣泡），測試者在左（白色）
    const row = document.createElement('div');
    row.className = 'msg-row' + (m.from === 'scammer' ? ' right' : '');
    const av = document.createElement('div');
    av.className  = 'avatar';
    av.innerHTML  = '<img src="avatar1.png">';
    const bubble = document.createElement('div');
    bubble.className = 'bubble';
    bubble.innerHTML = `
      <div class="txt">${escapeHtml(m.text)}</div>
      <div class="meta"><span class="time">${m.time || ''}</span></div>
    `;
    row.appendChild(av);
    row.appendChild(bubble);
    chatArea.appendChild(row);
  });
  chatArea.scrollTop = chatArea.scrollHeight;
}
render();

sendBtn.addEventListener('click', () => {
  const v = chatInput.value.trim();
  if (!v) return;
  const msg = { type:'chat', from:'scammer', text:v, time:new Date().toLocaleTimeString() };
  messages.push(msg);
  render();
  chatInput.value = '';
  tx(msg);
});

// 詐騙端只同步聊天，不處理去識別化/還原
function onIncoming(m){
  if (m.type === 'chat') {
    messages.push(m);
    render();
  }
}
