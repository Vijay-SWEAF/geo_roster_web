document.addEventListener("DOMContentLoaded", function () {
    if (!window.managementDashboardData) return;

    const data = window.managementDashboardData;

    const trendCanvas = document.getElementById("monthlyTrendChart");
    if (trendCanvas) {
        new Chart(trendCanvas, {
            type: "line",
            data: {
                labels: data.trendLabels,
                datasets: [
                    {
                        label: "Present",
                        data: data.trendPresent,
                        borderWidth: 2,
                        tension: 0.25
                    },
                    {
                        label: "Absent",
                        data: data.trendAbsent,
                        borderWidth: 2,
                        tension: 0.25
                    },
                    {
                        label: "Leave",
                        data: data.trendLeave,
                        borderWidth: 2,
                        tension: 0.25
                    },
                    {
                        label: "Half Day",
                        data: data.trendHalf,
                        borderWidth: 2,
                        tension: 0.25
                    }
                ]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: "top"
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    const categoryCanvas = document.getElementById("categoryChart");
if (categoryCanvas) {
    new Chart(categoryCanvas, {
        type: "bar",
        data: {
            labels: data.categoryLabels,
            datasets: [
                {
                    label: "Present",
                    data: data.categoryPresent,
                    borderWidth: 1,
                    maxBarThickness: 70,
                    categoryPercentage: 0.6,
                    barPercentage: 0.8
                },
                {
                    label: "Absent",
                    data: data.categoryAbsent,
                    borderWidth: 1,
                    maxBarThickness: 70,
                    categoryPercentage: 0.6,
                    barPercentage: 0.8
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            aspectRatio: 1.4,
            plugins: {
                legend: {
                    position: "top"
                }
            },
            scales: {
                y: {
                    beginAtZero: true
                }
            }
        }
    });
}
        const donutCanvas = document.getElementById("branchDonutChart");

if (donutCanvas) {
    const presentTotals = data.donutPresent || [];
    const absentTotals = data.donutAbsent || [];
    const labels = data.donutLabels || [];

    const finalLabels = [];
    const finalData = [];
    const backgroundColors = [];

    labels.forEach((label, index) => {
        const p = presentTotals[index] || 0;
        const a = absentTotals[index] || 0;

        if (p > 0) {
            finalLabels.push("Present (" + p + ")");
            finalData.push(p);
            backgroundColors.push("#3b82f6"); // blue
        }

        if (a > 0) {
            finalLabels.push("Absent (" + a + ")");
            finalData.push(a);
            backgroundColors.push("#f87171"); // light red
        }
    });

    if (finalData.length > 0) {
        new Chart(donutCanvas, {
            type: "doughnut",
            data: {
                labels: finalLabels,
                datasets: [{
                    data: finalData,
                    backgroundColor: backgroundColors,
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        position: "top"
                    }
                }
            }
        });
    }
}
});