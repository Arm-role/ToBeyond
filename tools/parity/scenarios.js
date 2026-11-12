// Test states shared by the draft and the Godot build (scripts/debug_scenarios.gd).
// draft : JS run inside To_Beyond_Draft.html to reach the state.
// els   : name -> [draft CSS selector, Godot node path(s) under Main].
//         A selector matching several nodes is compared item by item with
//         "Path/*" (every Control child) or an array of paths.
const HAND = [['red','N'],['red','N'],['blue','E'],['blue','E'],['green','S'],['orange','W'],['red','S'],['blue','W']];
const setHand = `hand=${JSON.stringify(HAND)}.map((c,i)=>({id:9000+i,type:c[0],dir:c[1]}));fresh=new Set();coins=25;renderTray();updateCoins();refreshCalc();`;
const P = 'Preview/PreviewHBox/', A = 'BottomSection/ControlsRow/ActionCol/';
const MAIN = {
  'stage': ['#stat', 'TopBar/StageLabel'],
  'coins': ['#coins', 'TopBar/CoinsLabel'],
  'speed btn': ['#spd', 'TopBar/SpeedBtn'],
  'restart btn': ['#rst', 'TopBar/RestartBtn'],
  'hero pic': ['#hero', P + 'HeroCol/HeroPic'],
  'calc': ['#calc', 'Preview/CalcLabel'],
  'hero hp bar': ['.php .hpbar', P + 'HeroCol/PhpBox/HeroHPBar'],
  'hero hp text': ['.php .hptxt', P + 'HeroCol/PhpBox/HeroHPText'],
  'enemy name': ['#ename', P + 'EnemyCol/EnemyName'],
  'enemy skill': ['#eskill', P + 'EnemyCol/EnemySkill'],
  'enemy pic': ['#epic', P + 'EnemyCol/EnemyPic'],
  'enemy hp bar': ['.enemy>.hpbar', P + 'EnemyCol/EnemyHPBar'],
  'enemy hp text': ['.enemy>.hptxt', P + 'EnemyCol/EnemyHPText'],
  'enemy atk': ['#eatk', P + 'EnemyCol/EnemyAtkText'],
  'msg': ['#msg', P + 'EnemyCol/MsgLabel'],
  'artifact slots': ['#artrow .islot', [1,2,3,4,5].map(i => 'ArtifactRow/Slot' + i)],
  'chaos slots': ['#chaosrow > *', 'ChaosRow/Slots/*'],
  'tiles': ['#board .tile', 'BoardSection/TilesContainer/*'],
  'board': ['#board', 'BoardSection/BoardBackground'],
  'hand cards': ['#tray .tcard', 'BottomSection/HandContainer/*'],
  'walk btn': ['#go', A + 'WalkBtn'],
  'sort colour': ['#sortCol', A + 'SortGroup/SortFrame/HBox/SortColorBtn'],
  'sort dir': ['#sortDir', A + 'SortGroup/SortFrame/HBox/SortDirBtn'],
  'discard btn': ['#dis', A + 'DiscardBtn'],
  'deck btn': ['.toolcol .vbtn:nth-child(1)', 'ToolCol/DeckCountBtn'],
  'stone btn': ['.toolcol .vbtn:nth-child(2)', 'ToolCol/StoneBtn'],
};
const S = 'ShopModal/ShopVBox/';
module.exports = {
  HAND,
  // Named crops (CSS px of the 1280x720 page) for --region.
  REGIONS: { top: [0, 0, 1280, 330], board: [0, 300, 1280, 240], bottom: [0, 520, 1280, 200], center: [200, 40, 880, 640] },
  SCENARIOS: {
    main: { draft: setHand, els: MAIN },
    placed: { draft: setHand + `selIds=new Set(hand.map(c=>c.id));autoPlace();`, wait: 1500,
      els: Object.assign({ 'group strip': ['#gstrip > *', 'BoardSection/GstripContainer/*'] }, MAIN) },
    arts: { draft: setHand + `[['add5','+10','blue',5],['mult2','+5','red',6],['atk15','A×1.5','blue',6]].forEach(([type,label,color,price],i)=>{ITEMS[i]={type,label,color,price,m:0};});renderItems();refreshCalc();`, els: MAIN },
    rare: { draft: setHand + `[['add5','+10','blue',5],['stoneUp','S','purple',6],['north5','N5','orange',6]].forEach(([type,label,color,price],i)=>{ITEMS[i]={type,label,color,price,m:type==='stoneUp'?1:0};});renderItems();refreshCalc();`, els: MAIN },
    boss: { draft: `spawnEnemy();spawnEnemy();document.querySelector('.enemy').classList.remove('spawn');` + setHand + `hand[6]={id:9006,type:'blank',dir:null};hand[7]={id:9007,type:'blank',dir:null};renderTray();chaos=[chaosFromDef(CHAOS_SHOP.find(d=>d.k==='mtile')),chaosFromDef(CHAOS_SHOP.find(d=>d.k==='color'&&d.a==='red')),chaosFromDef(CHAOS_SHOP.find(d=>d.k==='tdir'&&d.a==='W'))];tileChaos.mt.add(2);tileChaos.xm.add(5);tileChaos.xa.add(5);renderChaos();refreshCalc();discoverToast(4);chaosMsg('แตะช่องที่ต้องการวาง');`,
      els: MAIN },
    win: { draft: setHand + `rewardInfo={base:4,left:2,held:21,interest:4,arti:0,fate:0,cry:0,wc:0};showReward();`,
      els: { 'title': ['#reward h2', 'RewardModal/VBox/Title'], 'rows': ['#rewardRows .rrow', 'RewardModal/VBox/RewardInfo/*'], 'next btn': ['#reward .shopgo', 'RewardModal/VBox/NextBtn'] } },
    shop: { draft: setHand + `openShop();`,
      els: { 'shop': ['#shop', 'ShopModal'], 'title': ['.shophead h2', S + 'ShopHeader/ShopTitle'], 'coins': ['#shopCoins', S + 'ShopHeader/ShopCoinsLabel'],
        'leave btn': ['#shop .shopgo', S + 'ShopHeader/ShopLeaveBtn'],        'tabs': ['.shoptabs button', S + 'ShopBody/ShopTabs/*'] } },
    lose: { draft: `showGameOver();`,
      els: { 'panel': ['#gameover .panel', 'GameOverModal/Center/Panel'], 'title': ['#gameover .ptitle', 'GameOverModal/Center/Panel/VBox/Title'],
        'info': ['#goinfo', 'GameOverModal/Center/Panel/VBox/GameOverInfo'], 'retry btn': ['#gameover button', 'GameOverModal/Center/Panel/VBox/RetryBtn'] } },
    deck: { draft: setHand + `openDeckView();`,
      els: { 'panel': ['#vwDeck .panel', 'DeckModal/Center/Panel'], 'title': ['#vwDeckT', 'DeckModal/Center/Panel/VBox/Title'], 'close btn': ['#vwDeck button.sec', 'DeckModal/Center/Panel/VBox/CloseBtn'] } },
    stone: { draft: setHand + `openStoneView();`,
      els: { 'panel': ['#vwStone .panel', 'StoneModal/Center/Panel'], 'rows': ['#vwStoneB > *', 'StoneModal/Center/Panel/VBox/Scroll/List/*'], 'close btn': ['#vwStone button.sec', 'StoneModal/Center/Panel/VBox/CloseBtn'] } },
  },
  // Clicks for --seq (same spots on both pages): pick the first hand card,
  // press Walk to place it, then press Walk again to attack.
  SEQ_CLICKS: [[367, 601, 400], [477, 678, 900], [477, 678, 0]],
};
