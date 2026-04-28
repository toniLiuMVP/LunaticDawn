// list-page.js — 通用列表頁邏輯（DOM-only，不用 innerHTML）
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

  function num(n) { return n === 65535 || n === 255 ? '—' : String(n); }
  window.num = num; window.el = el;

  function renderTable(rows) {
    const content = $('content');
    content.replaceChildren();
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
      fields.forEach(f => {
        const td = el('td', f.class ? { class: f.class } : null, String(f.value));
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    content.appendChild(table);
    $('count').textContent = `${rows.length} / ${CFG.totalCount}`;
  }

  function toggleDetail(tr, row) {
    if (openDetail) {
      const wasOwner = openDetail._owner === tr;
      openDetail.remove(); openDetail = null;
      if (wasOwner) return;
    }
    const dtr = el('tr', { class: 'detail-row' });
    const dtd = el('td', { colspan: String(CFG.columns.length) });
    CFG.detailFn(dtd, row);
    dtr.appendChild(dtd); dtr._owner = tr;
    tr.parentNode.insertBefore(dtr, tr.nextSibling);
    openDetail = dtr;
  }

  function applyFilter() {
    const q = $('search').value.trim();
    const filtered = q
      ? allRows.filter(r => CFG.searchField(r).includes(q))
      : allRows;
    renderTable(filtered);
  }

  async function init() {
    try {
      const r = await fetch('game_data.json');
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const data = await r.json();
      allRows = data[CFG.dataKey];
      $('search').addEventListener('input', applyFilter);
      applyFilter();
    } catch (e) {
      $('content').replaceChildren(el('div', { class: 'error' }, '載入失敗: ' + e.message));
    }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
