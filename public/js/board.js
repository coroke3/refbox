const canvas = document.querySelector('#slide-canvas');
const drawing = document.querySelector('#drawing-layer');
const statusText = document.querySelector('#save-status');
const strokes = JSON.parse(document.querySelector('#stroke-data').textContent);
const workspace = document.querySelector('.board-workspace');
const libraryToggle = document.querySelector('#toggle-library');
let saveTimer;
let saveQueue = Promise.resolve();
let dirty = false;

function setLibraryClosed(closed) {
  workspace.classList.toggle('library-closed', closed);
  libraryToggle.setAttribute('aria-expanded', String(!closed));
  libraryToggle.setAttribute('aria-label', closed ? 'ライブラリを開く' : 'ライブラリを折りたたむ');
  libraryToggle.title = libraryToggle.getAttribute('aria-label');
  const icon = libraryToggle.querySelector('i');
  if (icon) icon.className = closed ? 'fas fa-chevron-right' : 'fas fa-chevron-left';
  sessionStorage.setItem('boardLibraryClosed', closed ? '1' : '0');
}
setLibraryClosed(sessionStorage.getItem('boardLibraryClosed') === '1');
libraryToggle.addEventListener('click', () => setLibraryClosed(!workspace.classList.contains('library-closed')));

function slideData() {
  const number = value => Math.round(parseFloat(value) * 100) / 100;
  return {
    refs: [...canvas.querySelectorAll('.canvas-reference')].map(item => ({
      id: Number(item.dataset.id), x: number(item.style.left), y: number(item.style.top), w: number(item.style.width)
    })),
    notes: [...canvas.querySelectorAll('.canvas-note')].map(item => ({
      id: item.dataset.noteId, text: item.querySelector('textarea').value,
      x: number(item.style.left), y: number(item.style.top), w: number(item.style.width)
    })),
    strokes
  };
}

function saveNow() {
  clearTimeout(saveTimer);
  if (!dirty) return saveQueue;
  dirty = false;
  const body = JSON.stringify(slideData());
  statusText.textContent = '保存中…';
  saveQueue = saveQueue.catch(() => {}).then(() => fetch(canvas.dataset.saveUrl, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body
  })).then(response => {
    if (response.status !== 204) throw new Error('保存できませんでした');
    statusText.textContent = '保存済み';
  }).catch(() => { dirty = true; statusText.textContent = '保存失敗 · もう一度保存してください'; });
  return saveQueue;
}

function scheduleSave() {
  dirty = true;
  statusText.textContent = '未保存';
  clearTimeout(saveTimer);
  saveTimer = setTimeout(saveNow, 350);
}

function moveItem(item, grip, event, resize = false) {
  event.preventDefault();
  const startX = parseFloat(item.style.left);
  const startY = parseFloat(item.style.top);
  const startWidth = parseFloat(item.style.width);
  const startPointerX = event.clientX;
  const startPointerY = event.clientY;
  const rect = canvas.getBoundingClientRect();
  grip.setPointerCapture(event.pointerId);

  function moving(pointer) {
    const dx = (pointer.clientX - startPointerX) / rect.width * 100;
    const dy = (pointer.clientY - startPointerY) / rect.height * 100;
    if (resize) {
      const min = item.classList.contains('canvas-note') ? 12 : 10;
      item.style.width = `${Math.max(min, Math.min(70, 100 - startX, startWidth + dx))}%`;
    } else {
      item.style.left = `${Math.max(0, Math.min(100 - startWidth, startX + dx))}%`;
      item.style.top = `${Math.max(0, Math.min(90, startY + dy))}%`;
    }
  }

  function finished() {
    grip.removeEventListener('pointermove', moving);
    grip.removeEventListener('pointerup', finished);
    grip.removeEventListener('pointercancel', finished);
    scheduleSave();
  }
  grip.addEventListener('pointermove', moving);
  grip.addEventListener('pointerup', finished);
  grip.addEventListener('pointercancel', finished);
}

let selectedItem = null;

function selectItem(item) {
  if (selectedItem && selectedItem !== item) selectedItem.classList.remove('is-selected');
  selectedItem = item;
  if (item) item.classList.add('is-selected');
}

function removeItem(item) {
  if (selectedItem === item) selectedItem = null;
  item.remove();
  dirty = true;
  saveNow();
}

function wireItem(item) {
  item.addEventListener('pointerdown', event => {
    if (event.target.closest('.remove-item')) return;
    selectItem(item);
  });
  item.querySelector('.drag-grip')?.addEventListener('pointerdown', event => moveItem(item, event.currentTarget, event));
  item.querySelector('.resize-grip')?.addEventListener('pointerdown', event => moveItem(item, event.currentTarget, event, true));
  const removeBtn = item.querySelector('.remove-item');
  if (removeBtn) {
    removeBtn.addEventListener('pointerdown', event => event.stopPropagation());
    removeBtn.addEventListener('click', event => {
      event.stopPropagation();
      event.preventDefault();
      removeItem(item);
    });
  }
  item.querySelector('textarea')?.addEventListener('input', scheduleSave);
  item.querySelector('textarea')?.addEventListener('blur', saveNow);
}

canvas.addEventListener('pointerdown', event => {
  if (event.target === canvas) selectItem(null);
});

document.addEventListener('keydown', event => {
  if (['Delete', 'Backspace'].includes(event.key) && selectedItem && document.activeElement.tagName !== 'TEXTAREA') {
    event.preventDefault();
    removeItem(selectedItem);
  }
});

canvas.querySelectorAll('.canvas-item').forEach(wireItem);
document.querySelector('#save-slide').addEventListener('click', saveNow);
document.querySelector('#add-note').addEventListener('click', () => {
  document.querySelector('[data-tool="select"]').click();
  const note = document.createElement('div');
  note.className = 'canvas-note canvas-item';
  note.dataset.noteId = crypto.randomUUID();
  note.style.cssText = 'left:35%;top:30%;width:25%';
  note.innerHTML = `
    <div class="canvas-item-bar">
      <span class="drag-grip" title="ドラッグして移動"><i class="fas fa-grip-lines"></i></span>
      <button class="remove-item" type="button" title="付箋を削除" aria-label="付箋を削除"><i class="fas fa-times"></i></button>
    </div>
    <textarea maxlength="500" placeholder="メモを書く"></textarea>
    <span class="resize-grip" title="ドラッグしてサイズ変更"></span>
  `;
  canvas.append(note);
  wireItem(note);
  selectItem(note);
  note.querySelector('textarea').focus();
  scheduleSave();
});

document.querySelectorAll('[data-tool]').forEach(button => button.addEventListener('click', () => {
  document.querySelectorAll('[data-tool]').forEach(tool => tool.classList.toggle('active', tool === button));
  canvas.classList.toggle('is-pen', button.dataset.tool === 'pen');
}));

function drawPoint(event) {
  const rect = drawing.getBoundingClientRect();
  return [Math.round((event.clientX - rect.left) / rect.width * 1000), Math.round((event.clientY - rect.top) / rect.height * 562.5)];
}

drawing.addEventListener('pointerdown', event => {
  if (!canvas.classList.contains('is-pen')) return;
  event.preventDefault();
  drawing.setPointerCapture(event.pointerId);
  const points = [drawPoint(event)];
  const line = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
  drawing.append(line);

  function drawingMove(pointer) {
    if (points.length >= 500) return;
    points.push(drawPoint(pointer));
    line.setAttribute('points', points.map(point => point.join(',')).join(' '));
  }
  function drawingEnd() {
    drawing.removeEventListener('pointermove', drawingMove);
    drawing.removeEventListener('pointerup', drawingEnd);
    drawing.removeEventListener('pointercancel', drawingEnd);
    if (points.length > 1) { strokes.push(points); scheduleSave(); } else line.remove();
  }
  drawing.addEventListener('pointermove', drawingMove);
  drawing.addEventListener('pointerup', drawingEnd);
  drawing.addEventListener('pointercancel', drawingEnd);
});

document.querySelector('#undo-stroke').addEventListener('click', () => {
  if (!strokes.length) return;
  strokes.pop();
  drawing.lastElementChild?.remove();
  scheduleSave();
});

document.querySelectorAll('.library-panel form, .scenes-panel form, .scenes-panel a').forEach(target => {
  target.addEventListener(target.tagName === 'FORM' ? 'submit' : 'click', async event => {
    if (event.defaultPrevented || (!dirty && statusText.textContent !== '保存中…')) return;
    event.preventDefault();
    await saveNow();
    if (statusText.textContent !== '保存済み') return;
    if (target.tagName === 'FORM') target.submit(); else location.assign(target.href);
  });
});

const togglePublicForm = document.querySelector('#toggle-public-form');
const togglePublicBtn = document.querySelector('#toggle-public-btn');
if (togglePublicForm && togglePublicBtn) {
  togglePublicForm.addEventListener('submit', async event => {
    event.preventDefault();
    togglePublicBtn.disabled = true;
    try {
      const res = await fetch(togglePublicForm.action, {
        method: 'POST',
        headers: { 'Accept': 'application/json' }
      });
      if (res.ok) {
        const data = await res.json();
        const isPublic = Boolean(data.is_public);
        togglePublicBtn.className = `badge ${isPublic ? 'public-badge' : 'private-badge'}`;
        togglePublicBtn.setAttribute('aria-pressed', String(isPublic));
        togglePublicBtn.querySelector('i').className = `fas fa-${isPublic ? 'globe' : 'lock'}`;
        togglePublicBtn.querySelector('span').textContent = isPublic ? '公開' : '非公開';
      }
    } catch (e) {
      console.error(e);
    } finally {
      togglePublicBtn.disabled = false;
    }
  });
}
