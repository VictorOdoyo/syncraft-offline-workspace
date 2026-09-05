import {test,expect} from '@playwright/test';
import {PNG} from 'pngjs';
import {randomUUID} from 'node:crypto';

async function open(page){
 await page.goto('/');await page.waitForSelector('flutter-view');
 await page.locator('flt-semantics-placeholder').evaluate(el=>el.click()).catch(()=>{});
 await expect(page.getByRole('button',{name:'New inspection',exact:true})).toBeVisible();
}
async function connect(page,user='inspector'){
 await page.getByRole('button',{name:'Connect',exact:true}).click();
 await typeInto(page,page.getByRole('textbox',{name:'Username',exact:true}),user);
 await typeInto(page,page.getByRole('textbox',{name:'Password',exact:true}),'local-demo');
 await page.getByRole('button',{name:'Connect',exact:true}).last().click();
 await expect(page.getByText('Connected',{exact:true})).toBeVisible();
 await expect(page.getByText('0 pending edits',{exact:true})).toBeVisible();
}
async function typeInto(page,locator,value){await locator.click();await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText(value);await page.keyboard.press('Tab');await expect(locator).toHaveValue(value);}
async function pixels(page,testInfo,name){
 const data=await page.screenshot({path:testInfo.outputPath(`${name}.png`)});const png=PNG.sync.read(data);const colors=new Set();
 for(let i=0;i<png.data.length;i+=80)colors.add(`${png.data[i]},${png.data[i+1]},${png.data[i+2]}`);
 expect(colors.size).toBeGreaterThan(30);
 await testInfo.attach(name,{body:data,contentType:'image/png'});
}
test('create offline, reload from cache, then synchronize',async({page,context},testInfo)=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await open(page);await page.evaluate(()=>navigator.serviceWorker.ready);
 await expect.poll(()=>page.evaluate(()=>Boolean(navigator.serviceWorker.controller))).toBe(true);
 await context.setOffline(true);
 const title=`Offline pump ${randomUUID().slice(0,8)}`;
 await page.getByRole('button',{name:'New inspection',exact:true}).click();
 await typeInto(page,page.getByRole('textbox',{name:/Inspection title/}),title);
 await typeInto(page,page.getByRole('textbox',{name:/^Site/}),'North waterworks');
 await page.getByRole('button',{name:'Create',exact:true}).click();
 await expect(page.getByText('4 pending edits',{exact:true})).toBeVisible();
 await page.reload();await page.waitForSelector('flutter-view');await page.locator('flt-semantics-placeholder').evaluate(el=>el.click()).catch(()=>{});
 await expect(page.getByRole('button',{name:new RegExp(title)})).toBeVisible();
 await context.setOffline(false);await connect(page);
 await typeInto(page,page.getByRole('textbox',{name:'Search inspections',exact:true}),title);
 await page.getByRole('button',{name:new RegExp(title)}).click();
 await page.getByRole('button',{name:'Edit notes',exact:true}).click();
 await typeInto(page,page.getByRole('textbox',{name:/Field notes/}),'Seal checked after offline reload.');
 await page.getByRole('button',{name:'Save',exact:true}).click();
 await expect(page.getByText('0 pending edits',{exact:true})).toBeVisible();
 await expect(page.getByRole('group',{name:'Seal checked after offline reload.',exact:true})).toBeVisible();
 await pixels(page,testInfo,'offline-inspection');expect(errors).toEqual([]);
});

test('two device edits remain visible until explicit resolution',async({browser,request},testInfo)=>{
 const api='http://127.0.0.1:8091/api/v1';const login=await request.post(`${api}/login`,{data:{username:'inspector',password:'local-demo'}});const {token}=await login.json();
 const device=randomUUID(),record=randomUUID(),title=`Concurrent review ${record.slice(0,8)}`;
 const headers={Authorization:`Bearer ${token}`,'X-Device-ID':device};
 expect((await request.post(`${api}/devices`,{headers,data:{id:device,name:'Browser test setup'}})).status()).toBe(201);
 const operations=Object.entries({title,site:'Riverside depot',notes:'Initial reading',status:'draft',priority:'high'}).map(([field,value])=>({id:randomUUID(),record,field,value,parents:[]}));
 expect((await request.post(`${api}/sync/push`,{headers,data:{operations}})).status()).toBe(200);
 const a=await browser.newContext({baseURL:'http://127.0.0.1:5176',viewport:testInfo.project.use.viewport});const b=await browser.newContext({baseURL:'http://127.0.0.1:5176',viewport:testInfo.project.use.viewport});
 const first=await a.newPage(),second=await b.newPage();
 try{
  await open(first);await connect(first);await typeInto(first,first.getByRole('textbox',{name:'Search inspections',exact:true}),title);await first.getByRole('button',{name:new RegExp(title)}).click();
  await open(second);await connect(second,'reviewer');await typeInto(second,second.getByRole('textbox',{name:'Search inspections',exact:true}),title);await second.getByRole('button',{name:new RegExp(title)}).click();
  for(const page of [first,second])await page.getByRole('button',{name:'Pause synchronization',exact:true}).click();
  for(const [page,value] of [[first,'North reading'],[second,'South reading']]){
   await page.getByRole('button',{name:'Edit notes',exact:true}).click();await typeInto(page,page.getByRole('textbox',{name:/Field notes/}),value);await page.getByRole('button',{name:'Save',exact:true}).click();
  }
  await first.getByRole('button',{name:'Resume synchronization',exact:true}).click();await expect(first.getByText('0 pending edits',{exact:true})).toBeVisible();
  await second.getByRole('button',{name:'Resume synchronization',exact:true}).click();await expect(second.getByText('0 pending edits',{exact:true})).toBeVisible();
  await expect(first.getByRole('button',{name:'Resolve',exact:true})).toBeVisible();
  const conflict=first.getByRole('group',{name:/^Concurrent edits notes/});
  await expect(conflict).toHaveAccessibleName(/North reading/);
  await expect(conflict).toHaveAccessibleName(/South reading/);
  await pixels(first,testInfo,'concurrent-values');
  await first.getByRole('button',{name:'Resolve',exact:true}).click();await typeInto(first,first.getByRole('textbox',{name:/Field notes/}),'Both readings verified');await first.getByRole('button',{name:'Save',exact:true}).click();
  await expect(first.getByRole('button',{name:'Resolve',exact:true})).toHaveCount(0);
  await expect(second.getByRole('group',{name:'Both readings verified',exact:true})).toBeVisible();
 }finally{await a.close();await b.close();}
});
