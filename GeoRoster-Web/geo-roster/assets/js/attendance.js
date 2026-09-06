document.addEventListener("DOMContentLoaded", function () {
    const table = document.getElementById("attendanceTable");
    if (!table) return;

const rows = document.querySelectorAll("#attendanceTable .attendance-row");
const searchBox = document.getElementById("employeeSearch");
const statusFilter = document.getElementById("statusFilter");
const summaryBox = document.getElementById("attendanceSummary");
const bulkStatusSelect = document.getElementById("bulkStatusSelect");
const applyBulkStatusBtn = document.getElementById("applyBulkStatusBtn");

    function updateRowState(row) {
    const statusSelect = row.querySelector(".status-select");
    const leaveSelect = row.querySelector(".leave-select");
    const otInput = row.querySelector(".ot-input");
    const expenseInput = row.querySelector(".expense-input");
    const warningBox = row.querySelector(".leave-warning");

    if (!statusSelect) return;

    const status = statusSelect.value;

    row.dataset.status = status;
    row.classList.remove("status-p", "status-a", "status-l", "status-h", "status-wo");
    row.classList.add("status-" + status.toLowerCase());

    if (leaveSelect) {
    if (status === "L") {
        leaveSelect.style.opacity = "1";
        leaveSelect.style.pointerEvents = "auto";
        leaveSelect.style.backgroundColor = "";

        const selectedOption = leaveSelect.options[leaveSelect.selectedIndex];
        const balance = selectedOption ? parseFloat(selectedOption.getAttribute("data-balance")) || 0 : 0;
        const code = selectedOption ? selectedOption.getAttribute("data-code") || "" : "";

        if (warningBox) {
            if (leaveSelect.value !== "" && balance <= 0) {
                warningBox.textContent = code + " exhausted. On save, it will be treated as LWP.";
            } else {
                warningBox.textContent = "";
            }
        }
    } else {
        leaveSelect.value = "";
        leaveSelect.style.opacity = "0.6";
        leaveSelect.style.pointerEvents = "none";
        leaveSelect.style.backgroundColor = "#f8fafc";

        if (warningBox) {
            warningBox.textContent = "";
        }
    }
}

    if (status === "A" || status === "L" || status === "WO") {
    if (otInput) otInput.value = 0;
    if (expenseInput) expenseInput.value = 0;
}
}

    function applyFilters() {
        const searchValue = searchBox ? searchBox.value.toLowerCase().trim() : "";
        const filterValue = statusFilter ? statusFilter.value : "ALL";

        rows.forEach(function (row) {
            const rowText = row.innerText.toLowerCase();
            const rowStatus = row.dataset.status || "";

            const searchMatch = rowText.includes(searchValue);

            let statusMatch = true;
if (filterValue === "A") statusMatch = rowStatus === "A";
else if (filterValue === "L") statusMatch = rowStatus === "L";
else if (filterValue === "H") statusMatch = rowStatus === "H";
else if (filterValue === "WO") statusMatch = rowStatus === "WO";
else if (filterValue === "EXCEPTION") {
    statusMatch = rowStatus === "A" || rowStatus === "L" || rowStatus === "H" || rowStatus === "WO";
}

            row.style.display = (searchMatch && statusMatch) ? "" : "none";
        });
    }

    function updateSummary() {
let present = 0;
let absent = 0;
let leave = 0;
let half = 0;
let weeklyOff = 0;
let totalOT = 0;
let totalExpense = 0;

        rows.forEach(function (row) {
            const status = row.dataset.status || "P";

if (status === "P") present++;
if (status === "A") absent++;
if (status === "L") leave++;
if (status === "H") half++;
if (status === "WO") weeklyOff++;

            const otInput = row.querySelector(".ot-input");
            const expenseInput = row.querySelector(".expense-input");

            if (otInput) totalOT += parseFloat(otInput.value) || 0;
            if (expenseInput) totalExpense += parseFloat(expenseInput.value) || 0;
        });

        if (summaryBox) {
            summaryBox.innerHTML =
    "Present: " + present +
    " | Absent: " + absent +
    " | Leave: " + leave +
    " | Half Day: " + half +
    " | Weekly Off: " + weeklyOff +
    "<br>" +
    "Total OT Hours: " + totalOT.toFixed(2) +
    " | Total Other Expense: ₹ " + totalExpense.toFixed(2);
        }
    }

    rows.forEach((row, index) => {
        const statusSelect = row.querySelector(".status-select");
const leaveSelect = row.querySelector(".leave-select");
const otInput = row.querySelector(".ot-input");
const expenseInput = row.querySelector(".expense-input");

        updateRowState(row);

        if (!statusSelect) return;

        statusSelect.addEventListener("change", () => {
            updateRowState(row);
            applyFilters();
            updateSummary();
        });

        statusSelect.addEventListener("keydown", (e) => {
            if (e.key === "Enter") {
                e.preventDefault();
                const nextRow = rows[index + 1];
                if (nextRow) {
                    const nextStatus = nextRow.querySelector(".status-select");
                    if (nextStatus) nextStatus.focus();
                }
            }
        });

        if (otInput) {
            otInput.addEventListener("input", updateSummary);
            otInput.addEventListener("keydown", (e) => {
                if (e.key === "Enter") {
                    e.preventDefault();
                    const nextRow = rows[index + 1];
                    if (nextRow) {
                        const nextStatus = nextRow.querySelector(".status-select");
                        if (nextStatus) nextStatus.focus();
                    }
                }
            });
        }

        if (expenseInput) {
            expenseInput.addEventListener("input", updateSummary);
        }
        
        if (leaveSelect) {
    leaveSelect.addEventListener("change", () => {
        updateRowState(row);
        applyFilters();
        updateSummary();
    });
}
    });

    if (searchBox) {
        searchBox.addEventListener("input", applyFilters);
    }

    if (statusFilter) {
    statusFilter.addEventListener("change", function () {
        applyFilters();
        updateSummary();
    });
}

if (applyBulkStatusBtn && bulkStatusSelect) {
    applyBulkStatusBtn.addEventListener("click", function () {
        const bulkStatus = bulkStatusSelect.value;

        if (!bulkStatus) {
            alert("Please select a bulk status first.");
            return;
        }

        rows.forEach(function (row) {
            if (row.style.display === "none") return;

            const statusSelect = row.querySelector(".status-select");
            if (!statusSelect) return;

            statusSelect.value = bulkStatus;
            updateRowState(row);
        });

        applyFilters();
        updateSummary();
    });
}

updateSummary();
applyFilters();
});