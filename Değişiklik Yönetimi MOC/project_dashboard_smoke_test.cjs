const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(__dirname + '/MOC.html', 'utf8');
const inline = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)];
inline.forEach((match) => new Function(match[1]));

function pick(start, end) {
  const a = html.indexOf('function ' + start + '(');
  const b = html.indexOf('function ' + end + '(', a + 1);
  assert(a >= 0 && b > a);
  return html.slice(a, b);
}
const ctx = {
  LANG: 'tr',
  pT: (x) => x,
  pDate: (x) => x || '—',
  fmtMoney: (x) => String(x),
  esc: (x) => String(x ?? '').replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),
  projectCostTypeLabel: (x) => x,
  projectTaskStatusLabel: (x) => x,
  projectTaskDependencyNote: () => '',
  PROJECT_CTX: {
    project: {id:2,moc_id:2,name:'[DEMO] Paketleme hattı sensör yenilemesi',status:'ACTIVE',currency:'TRY', budget_planned:185000, planned_start:'2026-09-20', planned_end:'2026-10-28'},
    moc: {moc_no:'MOC-2026-0002',title:'[DEMO] Paketleme hattı sensör yenilemesi'},
    baselines: [], dependencies: [],
    phases: [{id:1,name:'Uygulama'},{id:2,name:'Doküman'},{id:3,name:'Eğitim'}],
    tasks: [
      {id:1,phase_id:1,title:'Biten görev',status:'DONE',planned_start:'2026-09-20',due_date:'2026-09-22'},
      {id:2,phase_id:2,title:'Açık görev',status:'IN_PROGRESS',progress:65,planned_start:'2026-09-23',due_date:'2026-09-29'},
      {id:3,phase_id:3,title:'<test>',status:'BLOCKED',planned_start:'2026-10-02',due_date:'2026-10-09'}
    ],
    milestones: [{name:'Onay',target_date:'2026-09-22',completed_at:'2026-09-22'}],
    people: [],
    costs: [
      {cost_type:'LABOR',planned:30000,actual:6500,currency:'TRY',planned_on:'2026-10-07',incurred_on:'2026-09-22'},
      {cost_type:'PURCHASE',planned:140000,actual:0,currency:'TRY',planned_on:'2026-09-30'},
      {cost_type:'OTHER',planned:100,actual:100,currency:'USD',incurred_on:'2026-09-22'}
    ]
  }
};
vm.createContext(ctx);
vm.runInContext(pick('projectTimelineMarkup','projectBaselineMarkup') + pick('projectProgressPercent','projectCostMarkup'), ctx);
const overview = ctx.projectOverviewMarkup();
const timeline = ctx.projectTimelineMarkup(ctx.PROJECT_CTX.tasks);
assert.match(overview, /Proje akışı/);
assert.match(overview, /Kaydedilen gider/);
assert.equal(ctx.projectProgressPercent(ctx.PROJECT_CTX.tasks),55);
assert.match(overview, /width:65%/);
assert.match(overview, /6500/);
assert.match(overview, /185000/);
assert.match(overview, /2026-09/);
assert.match(overview, /2026-10/);
assert.match(overview, /Diğer para birimleri ayrı gösterilir/);
assert.doesNotMatch(overview, /6600/);
assert.doesNotMatch(overview, /<test>/);
assert.match(timeline, /project-time-milestone/);
assert.match(timeline, /project-time-today|project-time-bar/);
assert.match(timeline, /&lt;test&gt;/);
let detail = '';
Object.assign(ctx, {
  ACTIVE_WORKSPACE:'project', PROJECT_TASK_VIEW:'list',
  document:{getElementById:()=>({}),querySelectorAll:()=>[]},
  projectShell:(x)=>{detail=x;}, projectRoleCanEdit:()=>true,projectCanManageTask:()=>true,
  projectTaskStatusLabel:(x)=>x,projectStatusLabel:(x)=>x,projectMilestoneTypeLabel:(x)=>x||'',
});
['projectLoadIndex','workspaceAc','projectBaselineCreate','projectMilestoneForm','projectEditForm','projectBindBoard'].forEach((key)=>ctx[key]=()=>{});
vm.runInContext(pick('projectBaselineMarkup','projectBaselineCreate')+pick('projectCostMarkup','projectCostForm')+pick('projectRenderDetail','projectEditForm'),ctx);
ctx.projectRenderDetail();
assert.match(detail,/prLinkedMoc/);
assert.match(detail,/Plan zaman çizelgesi/);
assert.match(detail,/Maliyet kalemleri/);
ctx.PROJECT_CTX.project.moc_id=null;
ctx.projectRenderDetail();
assert.match(detail,/Bağımsız proje/);
assert.doesNotMatch(detail,/prLinkedMoc/);
const savedTasks=ctx.PROJECT_CTX.tasks;
ctx.PROJECT_CTX.tasks=[];
ctx.projectRenderDetail();
assert.match(detail,/Projeyi başlatın/);
assert.match(detail,/prStarterTask/);
assert.match(detail,/prStarterInfo/);
assert.match(detail,/prStarterCost/);
ctx.PROJECT_CTX.tasks=savedTasks;
ctx.PROJECT_CTX.project.moc_id=2;
const ids=[...detail.matchAll(/\bid="([^"]+)"/g)].map(x=>x[1]);
assert.equal(ids.length,new Set(ids).size,'Detail must not contain duplicate IDs');
vm.runInContext(html.slice(html.indexOf('var I18N='),html.indexOf('function t(s)'))+
  html.slice(html.indexOf('var PT_EN='),html.indexOf('function projectRoleCanEdit()'))+
  pick('projectCostTypeLabel','projectOverviewMarkup'),ctx);
ctx.LANG='en';
ctx.projectRenderDetail();
assert.match(detail,/Cost analysis/);
assert.match(detail,/Project flow/);
assert.match(detail,/Plan timeline/);
assert.match(detail,/Planned budget/);
assert.match(detail,/Purchase/);
assert.doesNotMatch(detail,/>Maliyet analizi</);
ctx.PROJECT_CTX.project.moc_id=null;
ctx.PROJECT_CTX.tasks=[];
ctx.projectRenderDetail();
assert.match(detail,/Get your project started/);
assert.match(detail,/Add first task/);
ctx.PROJECT_CTX.project.moc_id=2;
ctx.PROJECT_CTX.tasks=savedTasks;
const projectPart=html.slice(html.indexOf('function workspaceAc('),html.indexOf('function go('));
const missing=[...projectPart.matchAll(/pT\('([^']+)'\)/g)].map(x=>x[1]).filter(x=>!ctx.PT_EN[x]&&!ctx.I18N[x]);
assert.deepEqual([...new Set(missing)],[],'All literal project UI labels must have English translations');
ctx.LANG='tr';ctx.projectRenderDetail();
console.log('Project overview and timeline smoke test passed.');
if (process.argv[2]) {
  const path = require('node:path');
  const target = path.resolve(process.argv[2]);
  fs.mkdirSync(path.dirname(target), {recursive:true});
  if (process.argv[3] === 'starter') {
    ctx.PROJECT_CTX.project.moc_id=null;
    ctx.PROJECT_CTX.tasks=[];
    ctx.projectRenderDetail();
  }
  const css = html.match(/<style>([\s\S]*?)<\/style>/)[1];
  fs.writeFileSync(target, '<!doctype html><html lang="tr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Proje görünümü kontrolü</title><style>'+css+'</style><body><main style="padding:20px;max-width:1400px;margin:auto">'+detail+'</main></body></html>');
}
