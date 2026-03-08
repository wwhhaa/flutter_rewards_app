const https = require('https');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const token = process.env.GITHUB_TOKEN || 'YOUR_GITHUB_TOKEN_HERE';
const repo = 'wwhhaa/flutter_rewards_app';
const desktopPath = path.join(require('os').homedir(), 'Desktop');
const zipPath = path.join(desktopPath, 'RewardsApp_Build.zip');
const extractPath = path.join(desktopPath, 'RewardsApp_APK');

const options = {
    hostname: 'api.github.com',
    path: `/repos/${repo}/actions/artifacts`,
    method: 'GET',
    headers: {
        'User-Agent': 'Node.js',
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28'
    }
};

https.get(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
        try {
            const json = JSON.parse(data);
            if (json.artifacts && json.artifacts.length > 0) {
                const downloadUrl = json.artifacts[0].archive_download_url;
                console.log('Found artifact download URL:', downloadUrl);
                downloadZip(downloadUrl);
            } else {
                console.error('No artifacts found. Response:', json);
            }
        } catch (e) {
            console.error('Error parsing JSON:', e);
        }
    });
}).on('error', err => console.error(err));

function downloadZip(url) {
    const dlOptions = {
        headers: {
            'User-Agent': 'Node.js',
            'Authorization': `Bearer ${token}`
        }
    };

    const request = https.get(url, dlOptions, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
            console.log('Redirecting to:', res.headers.location);
            const redirectReq = https.get(res.headers.location, (resRedir) => {
                const file = fs.createWriteStream(zipPath);
                resRedir.pipe(file);
                file.on('finish', () => {
                    file.close(() => {
                        console.log('Download completed:', zipPath);
                        setTimeout(extractAndMove, 1000); // 1-second delay for file release
                    });
                });
            });
            return;
        }

        const file = fs.createWriteStream(zipPath);
        res.pipe(file);
        file.on('finish', () => {
            file.close(() => {
                console.log('Download completed:', zipPath);
                setTimeout(extractAndMove, 1000); // 1-second delay for file release
            });
        });
    });
}

function extractAndMove() {
    try {
        console.log('Extracting ZIP...');
        // Use powershell to extract
        execSync(`powershell -Command "Expand-Archive -Path '${zipPath.replace(/\\/g, '\\\\')}' -DestinationPath '${extractPath.replace(/\\/g, '\\\\')}' -Force"`);

        console.log('Moving APK to Desktop...');
        const apkSource = path.join(extractPath, 'app-release.apk');
        const apkDest = path.join(desktopPath, 'RewardsApp_Final.apk');

        if (fs.existsSync(apkSource)) {
            fs.copyFileSync(apkSource, apkDest);
            console.log(`Success! APK moved to: ${apkDest}`);

            // Cleanup
            fs.unlinkSync(zipPath);
            fs.rmSync(extractPath, { recursive: true, force: true });
            console.log('Cleanup completed.');
        } else {
            console.error('APK file not found in extracted folder:', apkSource);
        }
    } catch (err) {
        console.error('Error during extraction/move:', err);
    }
}
