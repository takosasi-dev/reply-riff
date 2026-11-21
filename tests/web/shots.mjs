// 全部の画面を 5 つの大きさで撮る(UI の作り直しの前後を比べる。v0.3.0)。窓なし・消音・使い捨てのプロフィールの Chrome(lib.mjs)。
//     node tests/web/shots.mjs before   → build/web_shots/before/
//     node tests/web/shots.mjs after    → build/web_shots/after/
// 流れ: 読み込み中 → S0 → S1(切り替わりの途中も)→ S4 → 今日の曲 1 回目(押さずに止まる。途中で S5)→ S3 →
// もう1回(回 1・2 を返す = 新しい記録)→ S3(押せない間・祝い・マウスが乗った・右クリックのメニュー)→ S1(記録あり)。
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { open, OUT, serve, sleep } from './lib.mjs';

const DIR = path.join(OUT, process.argv[2] || 'after');
mkdirSync(DIR, { recursive: true });
const SIZES = [[1280, 720], [1920, 1080], [1024, 768], [2560, 1080], [390, 844]];
const KEYS = ['a', 's', 'd', 'f', 'j', 'k', 'l', ';'];
const BAR = 288, EIGHTH = 36;
const replyStart = (t) => BAR + 2 * BAR * t + BAR;
const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const metrics = (w, h) => page.cdp.send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: w < 600 });
const one = (label) => page.shot(path.join(path.relative(OUT, DIR), label));

async function all(label, settle = 350) {
	for (const [w, h] of SIZES) {
		await metrics(w, h);
		await sleep(settle);
		await one(`${label}_${w}x${h}`);
	}
	await metrics(1280, 720);
	await sleep(200);
}

async function reply(t) {
	const s = await page.waitState((st) => st.play && st.play.tick >= replyStart(t) - 60 && st.play.tick < replyStart(t), 20000);
	if (!s) return false;
	const ph = s.play.phrase[t];
	const c = { tick: s.play.tick, at: Date.now() };
	for (let i = 0; i < ph.pos.length; i++) {
		const ms = c.at + ((replyStart(t) + ph.pos[i] * EIGHTH - c.tick) * 1000) / 120 - Date.now();
		if (ms > 0) await sleep(ms);
		page.down(KEYS[ph.keys[i]]);
		setTimeout(() => page.up(KEYS[ph.keys[i]]), 90);
	}
	return true;
}

const mouse = async (type, gx, gy, button = 'none') => {
	const [x, y] = await page.gameCss(gx, gy);
	await page.cdp.send('Input.dispatchMouseEvent', { type, x, y, button, clickCount: button === 'none' ? 0 : 1 });
};

const t0 = Date.now();
try {
	console.log(`起動(Godot の印字まで ${page.bootMs} ms)`);
	await page.waitState((s) => s.screen === 'gate', 30000);
	console.log(`S0 まで ${Date.now() - page.t0} ms`);
	await sleep(500);
	await all('s0');
	await page.key('x');
	await sleep(60);
	await one('trans_out_1280x720');
	await sleep(120);
	await one('trans_in_1280x720');
	await page.waitState((s) => s.screen === 'title');
	await sleep(600);
	await all('s1_title');
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'settings');
	await sleep(500);
	await all('s4_settings');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title');
	await page.key('ArrowDown');
	await page.key('Enter');
	// 1 回目: 押さずに止まる(0 点)。回 2 のお手本で一時停止
	await page.waitState((s) => s.screen === 'play');
	await page.waitState((s) => s.play && s.play.tick >= 150, 5000);
	await one('s2_count_1280x720');
	await page.waitState((s) => s.play && s.play.section === 1 && s.play.turn === 1, 12000);
	await page.key('Escape');
	await page.waitState((s) => s.paused, 3000);
	await sleep(500);
	await all('s5_pause');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'result', 40000);
	await sleep(1500);
	await all('s3_result');
	// 2 回目: 回 1・2 を返す → 新しい記録
	await page.key('r');
	await page.waitState((s) => s.screen === 'play', 3000);
	await page.waitState((s) => s.play && s.play.section === 1 && s.play.call_pos.length >= 3, 8000);
	await one('s2_call_1280x720');
	await reply(0);
	await page.waitState((s) => s.play && s.play.judged >= 1, 3000);
	await sleep(200);
	await one('s2_judged_1280x720');
	await reply(1);
	await page.waitState((s) => s.play && s.play.judged >= 2, 3000);
	await page.waitState((s) => s.play && s.play.section === 1 && s.play.call_pos.length >= 2, 8000);
	await all('s2_play', 150);
	await page.waitState((s) => s.screen === 'result', 40000);
	await sleep(60);
	await one('s3_result_early_1280x720');
	await sleep(1400);
	await one('s3_result_newbest_1280x720');
	await sleep(1800);
	await all('s3_result2');
	await mouse('mouseMoved', 760, 586);
	await sleep(200);
	await one('s3_hover_1280x720');
	await mouse('mousePressed', 600, 480, 'right');
	await mouse('mouseReleased', 600, 480, 'right');
	await sleep(400);
	await one('s3_popup_1280x720');
	await mouse('mousePressed', 640, 700, 'left');  // メニューの外を押して閉じる
	await mouse('mouseReleased', 640, 700, 'left');
	await sleep(200);
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title', 3000);
	await sleep(600);
	await all('s1_title_record');
	// 読み込み中の画面(開き直してすぐ。キャッシュは切ってある)
	await page.cdp.send('Page.navigate', { url: page.url0 });
	for (const ms of [300, 700]) {
		await sleep(ms === 300 ? 300 : 400);
		await one(`loading_${ms}ms_1280x720`);
	}
	await page.waitState((s) => s.screen === 'gate', 30000);
	const errs = page.errors();
	console.log(`コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).slice(0, 5).join(' / ') : ''));
} catch (e) {
	console.log(`途中で止まった: ${e.stack ?? e}`);
} finally {
	await page.close();
	site.stop();
}
console.log(`撮った: ${DIR}(${Math.round((Date.now() - t0) / 1000)} 秒)`);
