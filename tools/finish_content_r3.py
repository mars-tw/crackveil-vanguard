"""Write the R3 handoff from completed receipts, without running the game."""
from pathlib import Path
import hashlib,json,subprocess,datetime
from content_r3_native import ROOT,OUT,write,sha,source_state

def read(path):return json.loads((OUT/path).read_text(encoding='utf8'))
def unique_attempts():
    native={};web={}
    paths=list((OUT/'tests/attempts').rglob('runner.json'))+[OUT/'tests/paired/runner.json']
    for path in paths:
        for row in json.loads(path.read_text(encoding='utf8')):
            key=hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest()
            native.setdefault(key,{'receipt':path.relative_to(OUT).as_posix(),'record':row})
    for path in list((OUT/'tests/attempts').rglob('browser-ledger.json'))+[OUT/'tests/browser-ledger.json']:
        for row in json.loads(path.read_text(encoding='utf8')):
            if row['mode'] not in ['assault','escort']:continue
            key=hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest()
            web.setdefault(key,{'receipt':path.relative_to(OUT).as_posix(),'record':row})
    result={'native_paired_calls':list(native.values()),'web_battle_pilot_calls':list(web.values()),'native_counts':{'total':len(native),'verified':sum(r['record']['status']=='VERIFIED' for r in native.values()),'blocked':sum(r['record']['status']!='VERIFIED' for r in native.values()),'exit_124':sum(r['record']['exit_code']==124 for r in native.values())},'web_counts':{'total':len(web),'exit_0':sum(r['record']['exit_code']==0 for r in web.values()),'exit_nonzero':sum(r['record']['exit_code']!=0 for r in web.values())},'final_source':'71815b15478526c9b264637bbeb50c6de2c2995d765b6211c840505e7289ba25','final_source_web_assault':'2 attempts: first no_clear at game 180.040066666666, second actual victory; cause of no_clear not established; no CPU-causation claim','final_source_native':'3 calls: assault verified, escort first runner wall timeout at 180/last logged game110.5, escort necessary retry with explicit360wall limit','count_method':'deduplicate identical receipt records copied across attempts; repeated runs with distinct actual record remain separate; UI-only capture modes excluded from Web battle denominator'}
    write(OUT/'tests/attempt-summary.json',result);return result

def main():
    runner=read('tests/paired/runner.json');assert len(runner)==2 and all(r['status']=='VERIFIED' for r in runner),'final two runs incomplete'
    samples=read('tests/samples.json');assert len(samples)==15 and all(not r['errors'] for r in samples),'current screenshot set incomplete'
    controls=read('tests/controls.json');assert len(controls)==8 and all(not r['errors'] for r in controls)
    profiles=Path.home()/'AppData/Roaming/Godot/app_userdata/Crackveil Vanguard'
    before=read('tests/default-profile-before.json');after={};metadata={}
    for name in before:
        path=profiles/name
        after[name]=sha(path) if path.is_file() else None
        metadata[name]={'exists':path.is_file(),'bytes':path.stat().st_size if path.is_file() else None,'mtime_ns':path.stat().st_mtime_ns if path.is_file() else None,'sha256':after[name]}
    differences=[name for name in before if before[name]!=after[name]]
    write(OUT/'tests/default-profile-after.json',after)
    write(OUT/'tests/profile-isolation.json',{'before_snapshot_scope':'before first game-mechanics scene; after editor imports','before_metadata_scope':'existence/absence and SHA only; size/mtime were not recorded before, so no retrospective before-stat claim','after_captured_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'after_metadata':metadata,'default_hash_differences':differences,'native_outer_boundary':'per-child APPDATA/LOCALAPPDATA plus CV_QA_PROFILE selected in autoload ready before loads; no machine/shell global environment changed','web_boundary':'fresh Playwright browser context for every case; no existing browser profile','early_unit_files':'four explicitly named qa_content_r3_unit_* saves created by our early unit runs in real userdata, removed by scoped cleanup; original six default names preserved','game_transactions':'real reads, writes, migration, journals and retries remain enabled under QA isolation'})
    assert not differences,'default profile hash changed'
    binding=read('tests/ci-source-binding.json');binding['current_state']=source_state();binding['final_source_manifest_sha256']=sha(OUT/'tests/source-hashes.json');binding['final_native_and_controls']='rerun after final footer text fix; current source SHA with pre/post unchanged, no QA-only exception used for final results';write(OUT/'tests/ci-source-binding.json',binding)
    attempts=unique_attempts();a=read('tests/paired/assault.json');e=read('tests/paired/escort.json')
    phase=lambda row,kind:next(p for p in row['phases'].values() if p['kind']==kind)
    af=phase(a,'front');ef=phase(e,'front');ap=phase(a,'pincer');ep=phase(e,'pincer')
    mechanics=read('tests/mechanics.json');ci=read('tests/gates/summary.json');builds=read('tests/builds.json')
    assert len(ci)==49 and all(r['status']=='VERIFIED' for r in ci)
    text=f'''# 內容 R3 交付：正式編成與跨局構築

版本 **0.32.0-content-r3**，基準 `ce94e02`。本輪已實作正式整備、三線十五個互斥節點、第一／第五局免費選擇及支援歸因；只做本機提交，沒有 push、部署或商店操作。R2 的獨立內容覆核 7.8/10 是歷史基準，**本輪尚未取得兩位內容評審的新分數，不宣稱已達 9 分**。

## 正式操作與可見結果

主選單按「免費整備・殘響／編成・殘響 → 出擊整備」，先選裂線突擊、星盾護送或先鋒標準。隊員／羈絆／專精各五項可橫向切換，沒有前置升級樹；各線成本依序 4／6／8／10／12 殘響，總共只能裝備一個節點。解鎖後另按一次裝備，畫面會先更新真正的三人名單與肖像，再確認出擊；直接使用未裝節點的原 R2 編成仍可行。

新檔或首次遷移有一次免費選擇。四次正式真戰敗或通關後提供第二次，早期零擊殺戰敗也計算；退出選單不算。第四次結果顯示「免費整備」，按原重新出擊入口會先進第五局前的整備，亦可保留原編成直接確認，不強迫花券。保存失敗時結果顯示「重試保存」，回整備會重試該次真結算，不重領殘響。

十五節點的實際收益、代價與有效條件見 [計畫契約](OPTIM_PLAN_CONTENT_R3.md)及 [catalog](../scripts/services/starting_build_catalog.gd)。歌者先發相對免費護送另有療唱冷卻 -25%，以全隊傷害 -10%交換；羈絆節點提供可正常使用的先發組合。散兵回收只降低隊長**近戰**，遠攻不受此代價；封隙整備實際反擊 10 秒、沒有 +8 治療，提示同步。楔形破盾的包抄代價只限真正預警／生效期間。封隙專用節點在無盡明示不再觸發，不留下無收益的移速代價；既有暫時反擊於無盡繼續到期。

## 同種子真實取捨

兩套都從正式選單、免費解鎖、裝備及種子出擊開始，seed **55210**，初始殘響／歷史結算／舊升級／金幣／通關進度等價。駕駛器只走正常選單訊號、移動與換陣輸入、既有自動升級和略過商店，不改 HP、DPS、遊戲時間或通關旗標。是自動駕駛實跑，不能稱真人試玩。

| 觀測 | 裂線突擊＋楔形破盾 | 星盾護送＋圓陣護送 |
|---|---:|---:|
| 初始總 HP | {a['initial']['total_hp']:.0f} | {e['initial']['total_hp']:.0f} |
| 正面實際陣形 | 楔形 | 圓陣 |
| 正面封合時間 | {af['seal_seconds']:.3f} 秒 | {ef['seal_seconds']:.3f} 秒 |
| 正面初段盾衛剩餘 HP 比例 | {af['first_second_guards'][0]['fraction']:.1%} | {ef['first_second_guards'][0]['fraction']:.1%} |
| 包抄實際承傷 | {ap['taken_delta']:.2f} | {ep['taken_delta']:.2f} |
| 包抄承傷／該段起始小隊最大 HP | {ap['taken_per_start_capacity']:.2%} | {ep['taken_per_start_capacity']:.2%} |
| 真通關時間 | {a['time']:.3f} 秒 | {e['time']:.3f} 秒 |
| 結束 HP／本局招募最大 HP | {a['ending']['hp']:.2f}/{a['ending']['all_recruited_max_hp']:.0f} | {e['ending']['hp']:.2f}/{e['ending']['all_recruited_max_hp']:.0f} |
| 結束存活人數 | {a['ending']['living']} | {e['ending']['living']} |
| 全局實際承傷／支援回復／減傷 | {a['ending']['taken']:.2f}/{a['ending']['healing']:.2f}/{a['ending']['prevented']:.2f} | {e['ending']['taken']:.2f}/{e['ending']['healing']:.2f}/{e['ending']['prevented']:.2f} |

突擊正面約快 {(1-af['seal_seconds']/ef['seal_seconds']):.1%}，實際破盾加傷 {a['benefits']['shield_damage']:.2f}；護送包抄歸一化承傷約低 {(1-ep['taken_per_start_capacity']/ap['taken_per_start_capacity']):.1%}。護送的圓陣正面替代能通過，但慢速代價確實存在。結束總 HP 沒有直接拿來證明護送優勢，因先發與後續招募生命不同。[兩份原始實跑與來源前後收據](content/r3/tests/paired/runner.json)保留完整 HP、承傷、回復、減傷、存活、實際換陣歷史。

## 測試、來源與保全

- 既有 **48 項** CI 保留原斷言，加 R3 共 **49/49**；最初一輪 47/49 的 R43 真版面回歸與 C21 收據辨識問題已保留，修正後重跑 49。原 R2 **244/0**、R2.1 **120/0** 不放寬。後續 UI 修正只重跑 R29、R43、R3，最終 R3 **{mechanics['checks']}/0**。
- **8/8** 新頁真點擊案例：844×390、390×844、320×568、1366×600，各一般／最大介面字級；每例十八頁，另走免費解鎖、裝備、真名單、卸下、關閉、重開與出擊。切不同側面板會回到該節頂端，設定捲到末端後也能直接進整備。
- 最大字級下的四次真早敗 fixture 驗證三個結果按鈕均 ≥44 px、在視口內且不重疊，再以真 pointer 按「免費整備」進第五局。長免費／失敗文案曾真實溢出，原壞圖保留，兩分支現為短名「免費整備／重試保存」。
- MetaProgress 完整寫暫檔、讀回比對全內容（含未知設定），保存 journal／原檔校驗後替換；啟動先恢復再遷移／發券。涵蓋首檔與既有檔十二個受控中斷案例、合法卻缺後半的部分寫入、移除目標後失敗、半寫 journal、安裝完成後中斷及恢復本身失敗保留可恢復資料。非實際斷電／磁碟填滿認證。
- 真第四次結算一次保存失敗、後續殘響保存成功，仍由正常結果／整備路徑補記並發第二券；同 run 通關→繼續無盡→死亡只算一次里程碑，合法殘響差額可續領。舊非零貨幣、升級、徽記與未知設定均有保留測試。
- 630 檔來源 SHA 綁定 review／release PCK、每張圖的時間與 SHA；release 在無實體專案 fallback 的獨立檢查排除 **164** 個 debug 路徑。實際嵌入字型涵蓋新 UI／英雄文案 **760** 個漢字，missing=[]；沒有新增素材或不明字型。
- 預設六個 profile 在首次遊戲機制測試前有既有／缺席及 SHA 快照，時間在編輯器匯入之後；當時沒有記大小／mtime，沒有補造前值。最終 SHA 差異=[]，現在大小／mtime另存。所有正式 CI／實跑使用子程序 APPDATA／LOCALAPPDATA加 autoload 前 QA 路徑，交易仍真存真讀；Web 使用 fresh context。只清除本輪四個早期 QA 存檔。
- 原始 **2,671** 他人髒檔保護清冊、R2／R2.1 **192** 歷史檔保全；只把 supervisor 自有工單／導航的明確授權 SHA 變更列例外，不 stage。沒有改寫舊 tracked 驗證收據，所有新回收收據集中本輪。

完整 49 項執行時沒有先後 source hash 快照，runtime 是 junction；因此不聲稱它們具不可變的執行前來源證明。事後現值／mtime與後續受影響三 gate 的真先後 SHA 分開記於 [來源時序限制](content/r3/tests/ci-source-binding.json)。最終兩實跑、八 controls 與圖組使用最終一致來源，沒有使用早前 QA-only 例外冒充本輪結果。

## 十五張圖與嘗試分母

[精選圖清冊](content/r3/review-manifest.json)逐張列正式流程或 fixture、UTC 時間、版本、來源、包與 PNG SHA，全部未修圖。01–04 正式整備；05–08 兩套正面／包抄；09–11 同一護衛起手、命中、收招；12 真 pointer wheel 正常捲動露出戰術收益；13 直向支援歸因；14 最大介面字級的四次真早敗受控 fixture；15 正常重新出擊入口的第五局前免費選擇。14–15 有受控致死傷害，不能當自然遊玩。

最終來源的 Web 突擊取景 **2 次：1 次 180.04 遊戲秒未清、1 次正常通關**；未清原因未證實，不能歸因 CPU。護送此來源取景一次正常通關。最終原生 **3 次：突擊合格、護送第一次外部 180 秒 wall timeout（最後記錄遊戲 110.5 秒）、護送以明記 360 秒 wall 等待上限必要重跑合格**；沒有改遊戲 180 game／360 wall 政策或加速。這些失敗與來源改版前的其他嘗試全保留，總分母由 [attempt-summary](content/r3/tests/attempt-summary.json)逐筆去重記錄：原生 pilot {attempts['native_counts']['total']} 次／{attempts['native_counts']['verified']} 合格；Web battle pilot {attempts['web_counts']['total']} 次／{attempts['web_counts']['exit_0']} exit0。另有早期手機預設自動戰鬥被 QA helper 重複切關的取景中止、nil fixture 與已知 UID warning 堆疊分類失敗，都沒有改成成功。

## 尚未完成與品質界線

**其他一般／菁英通知的戰況優先層級待內容評審**：05／07 等原圖保留自動招募／菁英長通知占用部分戰場的現況，不能把 R2.1 裝備 loot 的窄修說成所有通知均不遮擋。擁擠戰況下的角色辨識、長結算捲動與戰鬥樂趣仍應由獨立內容評審判斷，技術全綠不能取代可見完成度。

實機、真人試玩、乾淨機效能由 owner 另安排，不在本次原評審計分範圍，也沒有宣稱通過；SwiftShader／Dummy 不能當裝置 p95。沒有進行新一輪三關自然長局普測或所有十五節點逐一自然通關，這些節點以真 Arena 受控機制回歸驗證。本輪未新增／重評美術、人物動畫、音效、美術資產或 H3 工作；聲音全程靜音，不能宣稱實聽品質。

清理自己的 export／.audit-tmp 時先移除已核對的 runtime junction 本身，再刪本輪副本；保留最新十五圖、指定四張早期基準與一張壞圖、全部 raw log／JSON。重拍重複 PNG 的路徑／SHA／bytes另列 [清理收據](content/r3/tests/cleanup.json)。工作前／後狀態及明確本輪檔案清單另存；只 stage 本輪檔案，沒有提交他人原有修改。

本輪報告與原始證據已備齊，**整體九分目標仍未由本輪技術交付證實**。最終本機 commit 以 `git log -1` 與 supervisor 的讀回核對為準。
'''
    (ROOT/'docs/CODEX_RESPONSE_CONTENT_R3.md').write_text(text,encoding='utf8',newline='\n')
    plan=ROOT/'docs/OPTIM_PLAN_CONTENT_R3.md'
    original=plan.read_text(encoding='utf8').split('\n## 實際驗收回填')[0]
    plan.write_text(original+f'\n## 實際驗收回填\n\n已完成正式編成、十五互斥節點、第一／第五局保證、交易恢復與正常 UI 重試、支援歸因。既有48＋新R3共49項通過；最終相關R29/R43/R3重驗，R3 {mechanics["checks"]}/0；四視口×兩字級8組新頁真點擊、兩套真連續通關及15張圖完成。最大字級免費／失敗按鈕短名修正已實拍。完整49沒有執行前hash，已如實列來源證明界線；最終實跑與後續gate另有先後hash。原始失敗與pilot未清不隱去，分母見attempt-summary。R2與R2.1證據凍結，指定foreign導航／工單只按owner授權SHA對帳。清理與local commit收尾見報告。一般／菁英通知遮擋仍待內容評審，未取得新評分，不宣稱九分。\n',encoding='utf8',newline='\n')
    print(json.dumps({'status':'handoff written','native_attempts':attempts['native_counts'],'web_attempts':attempts['web_counts'],'profile_differences':differences,'samples':len(samples)},ensure_ascii=False))

if __name__=='__main__':main()
