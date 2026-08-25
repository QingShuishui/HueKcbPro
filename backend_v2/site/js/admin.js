const loginPanel = document.getElementById('login-panel');
const dashboard = document.getElementById('dashboard');
const tokenForm = document.getElementById('token-form');
const tokenInput = document.getElementById('admin-token');
const formError = document.getElementById('form-error');
const metricGrid = document.getElementById('metric-grid');
const usersBody = document.getElementById('users-body');
const logsBody = document.getElementById('logs-body');
const refreshButton = document.getElementById('refresh-button');
const logoutButton = document.getElementById('logout-button');
const calendarStatus = document.getElementById('calendar-status');
const calendarRefreshButton = document.getElementById('calendar-refresh-button');

let adminToken = '';

function headers() {
  return { 'X-Admin-Token': adminToken };
}

async function fetchJson(path) {
  const response = await fetch(path, { headers: headers() });
  if (response.status === 401) {
    throw new Error('Token 无效');
  }
  if (!response.ok) {
    throw new Error(`请求失败：${response.status}`);
  }
  return response.json();
}

async function postJson(path) {
  const response = await fetch(path, { method: 'POST', headers: headers() });
  if (response.status === 401) throw new Error('Token 无效');
  if (!response.ok) throw new Error(`请求失败：${response.status}`);
  return response.json();
}

function text(value) {
  if (value === null || value === undefined || value === '') return '-';
  return String(value);
}

function formatTime(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function renderMetrics(summary) {
  const items = [
    ['总用户', summary.users.total],
    ['绑定学号', summary.users.bound],
    ['24h 活跃', summary.users.active_24h],
    ['7d 活跃', summary.users.active_7d],
    ['课表查询', summary.schedule.current_count],
    ['刷新请求', summary.schedule.refresh_count],
    ['平均耗时', `${summary.schedule.average_duration_ms}ms`],
    ['最大耗时', `${summary.schedule.max_duration_ms}ms`],
  ];

  metricGrid.innerHTML = items
    .map(([label, value]) => `<article class="metric-card"><span>${label}</span><strong>${value}</strong></article>`)
    .join('');
}

function renderUsers(users) {
  if (!users.length) {
    usersBody.innerHTML = '<tr><td class="empty-cell" colspan="7">暂无用户</td></tr>';
    return;
  }

  usersBody.innerHTML = users
    .map((user) => `
      <tr>
        <td>${text(user.user_id)}</td>
        <td>${text(user.academic_username)}</td>
        <td>${text(user.platform)}</td>
        <td>${text(user.app_version)}</td>
        <td>${text(user.app_build)}</td>
        <td>${text(user.device_name)}</td>
        <td>${formatTime(user.last_login_at)}</td>
      </tr>
    `)
    .join('');
}

function renderLogs(logs) {
  if (!logs.length) {
    logsBody.innerHTML = '<tr><td class="empty-cell" colspan="6">暂无日志</td></tr>';
    return;
  }

  logsBody.innerHTML = logs
    .map((log) => `
      <tr>
        <td>${formatTime(log.created_at)}</td>
        <td>${text(log.academic_username)}</td>
        <td>${text(log.action)}</td>
        <td>${text(log.status)}</td>
        <td>${text(log.duration_ms)}ms</td>
        <td>${text(log.error_message)}</td>
      </tr>
    `)
    .join('');
}

function renderCalendar(calendar) {
  if (!calendar) {
    calendarStatus.textContent = '尚未检测。请配置探测账号后重新检测。';
    return;
  }
  calendarStatus.textContent = `${calendar.term_id}：${calendar.semester_start_date} 至 ${calendar.semester_end_date}，共 ${calendar.total_weeks} 周；检测于 ${formatTime(calendar.detected_at)}`;
}

async function loadDashboard() {
  const [summary, users, logs, calendar] = await Promise.all([
    fetchJson('/api/v1/admin/monitor/summary'),
    fetchJson('/api/v1/admin/monitor/users'),
    fetchJson('/api/v1/admin/monitor/schedule-logs?limit=100'),
    fetchJson('/api/v1/admin/monitor/calendar'),
  ]);

  renderMetrics(summary);
  renderUsers(users.users);
  renderLogs(logs.logs);
  renderCalendar(calendar.calendar);
}

function enterDashboard() {
  loginPanel.hidden = true;
  dashboard.hidden = false;
}

function exitDashboard() {
  adminToken = '';
  tokenInput.value = '';
  dashboard.hidden = true;
  loginPanel.hidden = false;
  tokenInput.focus();
}

tokenForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  formError.textContent = '';
  adminToken = tokenInput.value.trim();
  if (!adminToken) return;

  try {
    await loadDashboard();
    enterDashboard();
  } catch (error) {
    adminToken = '';
    formError.textContent = error.message || '无法进入后台';
  }
});

refreshButton.addEventListener('click', async () => {
  await loadDashboard();
});

calendarRefreshButton.addEventListener('click', async () => {
  calendarRefreshButton.disabled = true;
  try {
    const calendar = await postJson('/api/v1/admin/monitor/calendar/refresh');
    renderCalendar(calendar);
  } catch (error) {
    calendarStatus.textContent = error.message || '重新检测失败';
  } finally {
    calendarRefreshButton.disabled = false;
  }
});

logoutButton.addEventListener('click', exitDashboard);
