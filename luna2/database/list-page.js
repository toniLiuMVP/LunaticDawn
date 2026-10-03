// list-page.js，通用列表頁邏輯
// 用法: <script>window.LIST_CONFIG = {...}</script><script src="list-page.js"></script>
// CONFIG: { dataKey, columns, searchField, getRowFields, detailFn, totalCount }

(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);
  function el(tag, attrs, ...children) {
    const e = document.createElement(tag);
    if (attrs) for (const [k, v] of Object.entries(attrs)) {
      if (k === 'class') e.className = v;
      else if (k === 'on') for (const [evt, fn] of Object.entries(v)) e.addEventListener(evt, fn);
      else e.setAttribute(k, v);
    }
    for (const c of children) {
      if (c == null || c === false) continue;
      e.appendChild(typeof c === 'string' || typeof c === 'number' ? document.createTextNode(String(c)) : c);
    }
    return e;
  }

  const CFG = window.LIST_CONFIG;
  let allRows = [];
  let openDetail = null;

  function num(n) { return n === 65535 || n === 255 ? '無' : String(n); }
  window.num = num; window.el = el;

  // 展開按鈕的 aria-expanded 跟著詳細列同步
  function setExpanded(row, on) {
    const btn = row && row.querySelector('button[aria-expanded]');
    if (btn) btn.setAttribute('aria-expanded', on ? 'true' : 'false');
  }

  function renderTable(rows) {
    const content = $('content');
    content.replaceChildren();
    openDetail = null; // 舊的詳細列已隨表格移除
    const table = el('table', { class: 'items-table' });
    const thead = el('thead'), trh = el('tr');
    CFG.columns.forEach(c => trh.appendChild(el('th', null, c)));
    thead.appendChild(trh); table.appendChild(thead);

    const tbody = el('tbody');
    for (const row of rows) {
      const fields = CFG.getRowFields(row);
      const tr = el('tr', {
        on: CFG.detailFn ? { click: () => toggleDetail(tr, row) } : {}
      });
      fields.forEach((f, i) => {
        const td = el('td', f.class ? { class: f.class } : null);
        if (i === 0 && CFG.detailFn) {
          // 第一欄放按鈕讓鍵盤也能展開；click 冒泡到 tr，由 tr 的 handler 處理
          const label = fields.length > 1 ? String(f.value) + ' ' + String(fields[1].value) : String(f.value);
          td.appendChild(el('button', { type: 'button', class: 'btn-reset', 'aria-expanded': 'false', 'aria-label': label }, String(f.value)));
        } else {
          td.appendChild(document.createTextNode(String(f.value)));
        }
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    // Wrap in a horizontal scroll container: body{overflow-x:hidden} in retro.css
    // propagates to the viewport, so a table wider than the screen has its right-hand
    // columns clipped AND unscrollable on mobile (measured at 375px: the rightmost
    // monster columns sat past x=375 with maxScrollLeft=0). Same pattern as npcs.html .table-scroll.
    const scroller = el('div', { class: 'table-scroll' });
    scroller.appendChild(table);
    content.appendChild(scroller);
    $('count').textContent = `${rows.length} / ${CFG.totalCount}`;
  }

  function toggleDetail(tr, row) {
    if (openDetail) {
      const wasOwner = openDetail._owner === tr;
      setExpanded(openDetail._owner, false);
      openDetail.remove(); openDetail = null;
      if (wasOwner) return;
    }
    const dtr = el('tr', { class: 'detail-row' });
    const dtd = el('td', { colspan: String(CFG.columns.length) });

    // 每筆附 toni 視角短評
    if (row.toni_note) {
      dtd.appendChild(el('div', {
        style: 'border-left: 3px solid var(--amber); background: rgba(255, 176, 0, 0.06); padding: 8px 12px; margin-bottom: 12px; font-size: 14px; color: var(--phosphor);'
      },
        el('b', { style: 'color: var(--amber); font-family: \'Press Start 2P\', monospace; font-size: 11px; display: block; margin-bottom: 4px;' }, '攻略筆記'),
        row.toni_note
      ));
    }

    CFG.detailFn(dtd, row);
    dtr.appendChild(dtd); dtr._owner = tr;
    tr.parentNode.insertBefore(dtr, tr.nextSibling);
    openDetail = dtr;
    setExpanded(tr, true);
  }

  // sanitize：raw hex 不公開，HTML 引用時顯示 placeholder
  function sanitizeRow(row) {
    if (!('_raw' in row)) row._raw = '';
    if (!('_raw_first_64' in row)) row._raw_first_64 = '';
    return row;
  }

  function applyFilter() {
    const q = $('search').value.trim();
    const filtered = q
      ? allRows.filter(r => CFG.searchField(r).includes(q))
      : allRows;
    renderTable(filtered);
  }

  async function init() {
    // 只在有滑鼠的桌機自動聚焦搜尋框，手機一開頁不跳出鍵盤
    if (window.matchMedia && window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
      $('search').focus();
    }
    try {
      const r = await fetch('game_data.json');
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const data = await r.json();
      allRows = data[CFG.dataKey].map(sanitizeRow);
      $('search').addEventListener('input', applyFilter);
      applyFilter();
    } catch (e) {
      $('content').replaceChildren(el('div', { class: 'error' }, '載入失敗: ' + e.message));
      $('count').textContent = '載入失敗';
    }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
