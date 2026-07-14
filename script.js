function logDownload() {
    document.getElementById("status").innerText = "Download started... Thank you for choosing NetPlus!";
    console.log("User clicked download button");
}

// كود بسيط للتحقق من الإصدار لاحقاً
async function checkVersion() {
    const response = await fetch('version.txt');
    const version = await response.text();
    console.log("Current version on server: " + version);
}

checkVersion();
