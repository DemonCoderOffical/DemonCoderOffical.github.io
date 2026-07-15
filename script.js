// نقوم بجلب رقم الإصدار من الملف
fetch('version.txt')
    .then(response => response.text())
    .then(version => {
        version = version.trim(); // تنظيف النص من أي مسافات
        console.log("Current Version: " + version);

        // هنا نقوم بتحديث الروابط ديناميكياً
        const winLink = document.getElementById('win-download');
        winLink.href = `downloads/NetPlus-${version}.exe`;
        winLink.innerText = `Download NetPlus ${version} for Windows`;
    });
