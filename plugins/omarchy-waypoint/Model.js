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

function monthCells(year, month, tasks) {
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
        cells.push({
            date: date,
            key: key,
            day: date.getDate(),
            inMonth: date.getMonth() === month,
            today: key === today,
            weekend: date.getDay() === 0 || date.getDay() === 6,
            pending: pending,
            completed: completed,
            overdue: overdue
        })
    }
    return cells
}

function tasksForDate(tasks, date) {
    const key = dateKey(date)
    return (tasks || []).filter(task => task.scheduledDate === key)
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
