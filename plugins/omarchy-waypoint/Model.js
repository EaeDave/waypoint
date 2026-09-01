function dateKey(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    return year + "-" + month + "-" + day
}

function parseLocalDate(value) {
    const parts = String(value || "").split("-")
    if (parts.length !== 3)
        return new Date(NaN)
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
}

function mondayIndex(jsDay) {
    return (jsDay + 6) % 7
}

function monthCells(year, month, tasks, holidays) {
    const first = new Date(year, month, 1)
    const start = new Date(year, month, 1 - mondayIndex(first.getDay()))
    const today = dateKey(new Date())
    const cells = []

    for (let index = 0; index < 42; ++index) {
        const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + index)
        const key = dateKey(date)
        let pending = 0
        let completed = 0
        let overdue = 0
        for (const task of tasks || []) {
            if (task.scheduledDate !== key)
                continue
            if (task.completed) {
                ++completed
            } else {
                ++pending
                if (key < today)
                    ++overdue
            }
        }
        const holidayEvents = (holidays || []).filter(holiday => holiday.date === key)
        const legalHoliday = holidayEvents.some(holiday => holiday.kind === "legal")
        cells.push({
            date: date,
            key: key,
            day: date.getDate(),
            inMonth: date.getMonth() === month,
            today: key === today,
            weekend: date.getDay() === 0 || date.getDay() === 6,
            pending: pending,
            completed: completed,
            overdue: overdue,
            holidays: holidayEvents,
            holidayCount: holidayEvents.length,
            legalHoliday: legalHoliday
        })
    }
    return cells
}

function isoWeek(date) {
    const value = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    const weekday = value.getUTCDay() || 7
    value.setUTCDate(value.getUTCDate() + 4 - weekday)
    const yearStart = new Date(Date.UTC(value.getUTCFullYear(), 0, 1))
    return Math.ceil(((value.getTime() - yearStart.getTime()) / 86400000 + 1) / 7)
}

function monthWeeks(year, month, tasks, holidays) {
    const cells = monthCells(year, month, tasks, holidays)
    const weeks = []
    for (let index = 0; index < 6; ++index) {
        const days = cells.slice(index * 7, index * 7 + 7)
        weeks.push({
            week: isoWeek(days[3].date),
            days: days
        })
    }
    return weeks
}

function yearProgress(date) {
    const year = date.getFullYear()
    const dayOfYear = Math.round((Date.UTC(year, date.getMonth(), date.getDate()) - Date.UTC(year, 0, 1)) / 86400000) + 1
    const daysInYear = Math.round((Date.UTC(year + 1, 0, 1) - Date.UTC(year, 0, 1)) / 86400000)
    return Math.max(0, Math.min(1, (dayOfYear - 1) / daysInYear))
}

function tasksForDate(tasks, date) {
    const key = dateKey(date)
    return (tasks || []).filter(task => task.scheduledDate === key)
}
function holidaysForDate(holidays, date) {
    const key = dateKey(date)
    return (holidays || []).filter(holiday => holiday.date === key)
}


function todaySummary(tasks) {
    const today = dateKey(new Date())
    let pending = 0
    let overdue = 0
    for (const task of tasks || []) {
        if (task.completed)
            continue
        if (task.scheduledDate === today)
            ++pending
        else if (task.scheduledDate < today)
            ++overdue
    }
    return { pending: pending, overdue: overdue }
}
