const times = [
    '上午 1-2节|08:00-09:40',
    '上午 3-4节|10:00-11:40',
    '下午 5-6节|14:00-15:40',
    '下午 7-8节|16:00-17:40',
    '晚上 9-10节|18:30-20:10',
    '晚上 11节|20:20-21:05'
];
const colors = ['pink', 'blue', 'yellow', 'purple', 'green'];
const courseNameAliases = new Map([
    ['毛泽东思想和中国特色社会主义理论体系概论', '毛概']
]);

function setCopyStatus(message, isError = false, targetId = 'settingsStatus') {
    const status = document.getElementById(targetId);
    if (!status) return;
    status.textContent = message;
    status.classList.toggle('is-error', isError);
    if (status._timer) {
        window.clearTimeout(status._timer);
    }
    if (message) {
        status._timer = window.setTimeout(() => {
            status.textContent = '';
            status.classList.remove('is-error');
        }, 2500);
    }
}

async function markLinkHintSeen() {
    const banner = document.getElementById('saveLinkBanner');
    if (!banner || banner.dataset.showLinkHint !== 'true') return;

    const response = await fetch(`/api/tokens/${window.scheduleToken}/link-hint-seen`, {
        method: 'POST'
    });

    if (!response.ok) {
        throw new Error('mark-link-hint-failed');
    }
    banner.dataset.showLinkHint = 'false';
}

function setActiveView(view) {
    document.querySelectorAll('[data-view]').forEach((section) => {
        const active = section.dataset.view === view;
        section.classList.toggle('is-active', active);
        section.hidden = !active;
    });

    document.querySelectorAll('[data-view-target]').forEach((trigger) => {
        const active = trigger.dataset.viewTarget === view;
        trigger.classList.toggle('is-active', active);
        if (trigger.classList.contains('nav-item')) {
            trigger.classList.toggle('active', active);
        }
    });
}

async function copyCurrentLink(statusTargetId = 'settingsStatus', hideBannerAfterCopy = false) {
    const link = window.savedLink || `${window.location.origin}/t/${window.scheduleToken}`;

    try {
        await navigator.clipboard.writeText(link);
        setCopyStatus('复制成功', false, statusTargetId);
        await markLinkHintSeen();
        if (hideBannerAfterCopy) {
            const banner = document.getElementById('saveLinkBanner');
            window.setTimeout(() => banner?.classList.add('is-hidden'), 2200);
        }
    } catch (error) {
        console.error(error);
        setCopyStatus('复制失败，请手动复制', true, statusTargetId);
    }
}

async function shareCurrentLink() {
    const link = window.savedLink || `${window.location.origin}/t/${window.scheduleToken}`;

    if (navigator.share) {
        try {
            await navigator.share({
                title: '课程表',
                text: '分享我的课程表链接',
                url: link
            });
            setCopyStatus('已调起系统分享');
            await markLinkHintSeen();
            return;
        } catch (error) {
            if (error?.name === 'AbortError') {
                return;
            }
        }
    }

    await copyCurrentLink();
}

async function saveSettings(event) {
    event.preventDefault();

    const username = document.getElementById('settingsUsername')?.value.trim();
    const password = document.getElementById('settingsPassword')?.value || '';
    const semesterStartDate = document.getElementById('settingsSemesterStartDate')?.value;

    try {
        const response = await fetch(`/api/tokens/${window.scheduleToken}/settings`, {
            method: 'PATCH',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username,
                password,
                semester_start_date: semesterStartDate
            })
        });
        const data = await response.json();

        if (!response.ok) {
            setCopyStatus(data.error || '保存失败', true);
            return;
        }

        window.initialSettings = {
            username,
            password,
            semester_start_date: semesterStartDate
        };
        setCopyStatus('设置已保存');
        fetchSchedule(document.getElementById('weekSelect')?.value || '');
    } catch (error) {
        console.error(error);
        setCopyStatus('保存失败，请稍后重试', true);
    }
}

function bindViewSwitches() {
    document.querySelectorAll('[data-view-target]').forEach((trigger) => {
        trigger.addEventListener('click', (event) => {
            event.preventDefault();
            setActiveView(trigger.dataset.viewTarget);
        });
    });
}

function bindSettingsControls() {
    document.getElementById('settingsForm')?.addEventListener('submit', saveSettings);
    document.getElementById('settingsCopyLinkButton')?.addEventListener('click', copyCurrentLink);
    document.getElementById('bannerCopyLinkButton')?.addEventListener('click', () => {
        copyCurrentLink('bannerCopyLinkStatus', true);
    });
    document.getElementById('settingsShareLinkButton')?.addEventListener('click', shareCurrentLink);
}

function extractLocationCode(loc) {
    if (!loc) return '';
    const match = loc.match(/^[A-Za-z0-9]+/);
    return match ? match[0] : loc;
}

function formatCourseName(name) {
    if (!name) return '';
    const normalizedName = String(name)
        .trim()
        .replace(/\s+补$/u, '/补')
        .replace(/\s*\/\s*/g, '/');
    return courseNameAliases.get(normalizedName) || normalizedName;
}

async function fetchSchedule(week) {
    const loading = document.getElementById('loading');
    const errorDiv = document.getElementById('error-msg');
    const timetable = document.getElementById('timetable');

    if (!loading || !errorDiv || !timetable || !window.scheduleToken) {
        return;
    }

    loading.style.display = 'flex';
    errorDiv.style.display = 'none';

    const headers = Array.from(timetable.children).slice(0, 8);
    timetable.innerHTML = '';
    headers.forEach((h) => timetable.appendChild(h));

    try {
        let url = `/api/schedule/${window.scheduleToken}`;
        if (week === 'all') {
            url += '?week=all';
        } else if (week) {
            url += `?week=${week}`;
        }

        if (typeof isWeekendFromServer !== 'undefined' && isWeekendFromServer && !week) {
            url += (week ? '&' : '?') + 'is_weekend=true';
        }

        const response = await fetch(url);
        const data = await response.json();

        if (data.error) {
            document.getElementById('error-text').innerText = data.error;
            errorDiv.style.display = 'block';
            return;
        }

        if (data.weekend_message) {
            showWeekendNotification(data.weekend_message);
        }

        updateUI(data);
    } catch (error) {
        console.error(error);
        document.getElementById('error-text').innerText = '网络请求失败';
        errorDiv.style.display = 'block';
    } finally {
        loading.style.display = 'none';
    }
}

function showWeekendNotification(message) {
    let notification = document.getElementById('weekend-notification');
    if (!notification) {
        notification = document.createElement('div');
        notification.id = 'weekend-notification';
        notification.className = 'weekend-notification';
        document.body.insertBefore(notification, document.body.firstChild);
    }

    notification.textContent = message;
    notification.style.display = 'block';

    setTimeout(() => {
        notification.style.display = 'none';
    }, 3000);
}

function updateDateStrip() {
    const today = new Date();
    const currentDay = today.getDay();
    const monday = new Date(today);
    const diff = currentDay === 0 ? -6 : 1 - currentDay;
    monday.setDate(today.getDate() + diff);

    document.querySelectorAll('.date-item').forEach((item, index) => {
        const date = new Date(monday);
        date.setDate(monday.getDate() + index);

        item.querySelector('.date-num').textContent = date.getDate();
        item.classList.toggle('today', date.toDateString() === today.toDateString());
    });
}

function updateUI(data) {
    document.getElementById('semester-info').innerText = data.semester_info || '';
    document.getElementById('generated-at').innerText = '生成时间: ' + data.generated_at;
    updateDateStrip();

    const gridContainer = document.getElementById('timetable');

    for (let timeIdx = 0; timeIdx < 6; timeIdx++) {
        const timeSlot = document.createElement('div');
        timeSlot.className = 'time-slot';
        const parts = times[timeIdx].split('|');
        timeSlot.innerHTML = `<span>${parts[1]}</span><span style="font-size: 0.7rem; font-weight: normal;">${parts[0]}</span>`;
        gridContainer.appendChild(timeSlot);

        for (let dayIdx = 0; dayIdx < 7; dayIdx++) {
            const key = `${timeIdx}-${dayIdx}`;
            const courses = data.grid[key];
            const delay = (timeIdx * 7 + dayIdx) * 0.03;

            if (courses && courses.length > 0) {
                const el = document.createElement('div');
                el.className = `course animate-in ${colors[(timeIdx + dayIdx) % 5]}`;
                el.style.animationDelay = `${delay}s`;

                const tooltipLines = courses
                    .map((course) => {
                        const parts = [];
                        if (course.weeks) parts.push('📅 ' + course.weeks);
                        if (course.teacher) parts.push('👤 ' + course.teacher);
                        return parts.join(' | ');
                    })
                    .filter(Boolean);

                if (tooltipLines.length > 0) {
                    const tooltip = document.createElement('div');
                    tooltip.className = 'course-tooltip';
                    tooltip.innerText = tooltipLines.join('\n');
                    el.appendChild(tooltip);
                }

                const name = document.createElement('div');
                name.className = 'course-name';
                name.innerText = courses
                    .map((course) => {
                        const baseName = formatCourseName(course.name);
                        return baseName + (course.code ? ' ' + course.code : '');
                    })
                    .filter(Boolean)
                    .join(' / ');
                el.appendChild(name);

                const detail = document.createElement('div');
                detail.className = 'course-detail';
                const uniqueLocations = [...new Set(courses.map((course) => extractLocationCode(course.location)).filter(Boolean))];
                if (uniqueLocations.length > 0) {
                    detail.innerHTML = `📍 ${uniqueLocations.join(' / ')}`;
                }
                el.appendChild(detail);

                gridContainer.appendChild(el);
            } else {
                const el = document.createElement('div');
                el.className = 'course empty animate-in';
                el.style.animationDelay = `${delay}s`;
                gridContainer.appendChild(el);
            }
        }
    }
}

function changeWeek() {
    const week = document.getElementById('weekSelect')?.value;
    fetchSchedule(week);
}

window.onload = () => {
    bindViewSwitches();
    bindSettingsControls();

    if (!window.scheduleToken) {
        return;
    }

    const urlParams = new URLSearchParams(window.location.search);
    let week = urlParams.get('week');
    if (!week) {
        week = document.getElementById('weekSelect')?.value;
    }
    fetchSchedule(week);
};
