// الكود الذي يكتشف نوع الجهاز
const platform = navigator.platform.toLowerCase();
const userAgent = navigator.userAgent.toLowerCase();

if (userAgent.includes("android")) {
    console.log("User is on Android");
    // هنا يمكننا تغيير نص أو إظهار زر خاص بالـ Termux
} else if (platform.includes("win")) {
    console.log("User is on Windows");
}
