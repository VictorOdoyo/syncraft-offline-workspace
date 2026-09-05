import {defineConfig} from '@playwright/test';
export default defineConfig({testDir:'e2e',timeout:90000,expect:{timeout:20000},workers:1,fullyParallel:false,
 use:{baseURL:'http://127.0.0.1:5176',trace:'retain-on-failure',screenshot:'only-on-failure'},
 projects:[{name:'desktop',use:{viewport:{width:1440,height:1000}}},{name:'mobile',use:{viewport:{width:390,height:844}}}],
 reporter:[['list'],['html',{open:'never'}]],
});
