import { LightningElement, api, wire, track } from 'lwc';
import getAccount from '@salesforce/apex/SugatiTravellerPageCtrl.getAccount';
import getOpportunities from '@salesforce/apex/SugatiTravellerPageCtrl.getOpportunities';
import getTasks from '@salesforce/apex/SugatiTravellerPageCtrl.getTasks';

const MMAX = 82;
const YMAX = 54;
const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const FONT_URL = 'https://fonts.googleapis.com/css2?family=Crimson+Pro:ital,wght@0,200;0,300;0,400;0,600;1,200;1,300&family=DM+Sans:wght@300;400;500;600&display=swap';

function mPx(pct) { return Math.max(3, Math.round(MMAX * pct / 100)) + 'px'; }
function yPx(pct) { return Math.max(3, Math.round(YMAX * pct / 100)) + 'px'; }

const B2B_DATA = {
    'LT':   { monthly:[62,68,82,74,92,100,95,88,76,64,48,38], yoy:{years:['2019','2020','2021','2022','2023','2024','2025'],heights:[18,12,48,65,84,100,100],sel:-1} },
    '2022': { monthly:[28,32,38,34,48,62,80,75,50,36,22,14],  yoy:{years:['2018','2019','2020','2021','2022'],heights:[10,18,12,48,65],sel:4} },
    '2023': { monthly:[32,38,48,42,60,76,92,88,62,44,28,18],  yoy:{years:['2019','2020','2021','2022','2023'],heights:[18,12,48,65,84],sel:4} },
    '2024': { monthly:[34,40,52,46,66,84,96,90,58,42,26,16],  yoy:{years:['2020','2021','2022','2023','2024'],heights:[12,48,65,84,100],sel:4} },
    '2025': { monthly:[38,42,55,48,70,88,100,92,60,45,30,20], yoy:{years:['2021','2022','2023','2024','2025'],heights:[48,65,84,100,100],sel:4} }
};

const SUP_DATA = {
    'LT':   { monthly:[45,48,62,70,85,100,78,90,82,68,52,35], yoy:{years:['2019','2020','2021','2022','2023','2024','2025'],heights:[20,8,30,48,62,82,100],sel:-1} },
    '2022': { monthly:[22,26,38,44,58,70,55,68,60,45,32,20],  yoy:{years:['2018','2019','2020','2021','2022'],heights:[12,20,8,30,48],sel:4} },
    '2023': { monthly:[26,30,44,52,66,80,65,75,68,55,38,24],  yoy:{years:['2019','2020','2021','2022','2023'],heights:[20,8,30,48,62],sel:4} },
    '2024': { monthly:[30,35,50,60,75,88,72,82,74,60,44,28],  yoy:{years:['2020','2021','2022','2023','2024'],heights:[8,30,48,62,82],sel:4} },
    '2025': { monthly:[34,39,59,67,87,97,74,91,79,61,43,27],  yoy:{years:['2021','2022','2023','2024','2025'],heights:[30,48,62,82,100],sel:4} }
};

function buildMonthlyBars(pcts) {
    return MONTHS.map((label, i) => ({ label, style: `height:${mPx(pcts[i])}` }));
}
function buildYoyBars(yoy) {
    return yoy.years.map((label, i) => ({
        label,
        cls:   i === yoy.sel ? 'bar' : 'bar secondary',
        style: `height:${yPx(yoy.heights[i])}`
    }));
}

export default class SugatiCrm extends LightningElement {

    // ── Record page props ──
    @api recordId;
    @track account;
    @track opportunities = [];
    @track tasks = [];
    // ── UI state ──
    @track activePage = 'b2c';
    @track b2bYear    = '2025';
    @track supYear    = '2025';

    // @track _account;
    // ── Wire: Account ──
    @wire(getAccount, { accountId: '$recordId' })
    wiredAccount({ data, error }) {
        if (data) {
            this.account = data;
            console.log('Account data:', JSON.stringify(data));
        } else if (error) {
            console.error('getAccount error:', JSON.stringify(error));
        }
    }
    renderedCallback() {
        console.log('renderedCallback — recordId:', this.recordId, '| account:', this.account);
        // font injection...
    }
    // ── Wire: Opportunities ──
    @wire(getOpportunities, { accountId: '$recordId' })
    wiredOpps({ data, error }) {
        if (data) {
            this.opportunities = data;
        } else if (error) {
            console.error('getOpportunities error:', JSON.stringify(error));
        }
    }

    @wire(getTasks, { accountId: '$recordId' })
    wiredTasks({ data, error }) {
        if (data) { this.tasks = data; 
            console.log('Tasks data:', JSON.stringify(data));
        }
        else if (error) { console.error('getTasks error:', JSON.stringify(error)); }
    }
        


    // ── Inject Google Fonts ──
    renderedCallback() {
        if (!document.head.querySelector('#sugati-fonts')) {
            const link = document.createElement('link');
            link.id   = 'sugati-fonts';
            link.rel  = 'stylesheet';
            link.href = FONT_URL;
            document.head.appendChild(link);
        }
    }

    // ── Page switchers ──
    get isB2c()      { return this.activePage === 'b2c'; }
    get isB2b()      { return this.activePage === 'b2b'; }
    get isSupplier() { return this.activePage === 'supplier'; }

    get tabClassB2c()      { return this.activePage === 'b2c'      ? 'nav-tab active' : 'nav-tab'; }
    get tabClassB2b()      { return this.activePage === 'b2b'      ? 'nav-tab active' : 'nav-tab'; }
    get tabClassSupplier() { return this.activePage === 'supplier' ? 'nav-tab active' : 'nav-tab'; }

    showB2c()      { this.activePage = 'b2c'; }
    showB2b()      { this.activePage = 'b2b'; }
    showSupplier() { this.activePage = 'supplier'; }

    // ── B2B year tabs ──
    get b2bYearClassLT()   { return this.b2bYear === 'LT'   ? 'year-tab lt-tab active' : 'year-tab lt-tab'; }
    get b2bYearClass2022() { return this.b2bYear === '2022' ? 'year-tab active' : 'year-tab'; }
    get b2bYearClass2023() { return this.b2bYear === '2023' ? 'year-tab active' : 'year-tab'; }
    get b2bYearClass2024() { return this.b2bYear === '2024' ? 'year-tab active' : 'year-tab'; }
    get b2bYearClass2025() { return this.b2bYear === '2025' ? 'year-tab active' : 'year-tab'; }

    setB2BYear(event) { this.b2bYear = event.currentTarget.dataset.year; }

    get b2bMonthlyBars() { return buildMonthlyBars((B2B_DATA[this.b2bYear] || B2B_DATA['2025']).monthly); }
    get b2bYoyBars()     { return buildYoyBars((B2B_DATA[this.b2bYear] || B2B_DATA['2025']).yoy); }

    // ── Supplier year tabs ──
    get supYearClassLT()   { return this.supYear === 'LT'   ? 'year-tab lt-tab active' : 'year-tab lt-tab'; }
    get supYearClass2022() { return this.supYear === '2022' ? 'year-tab active' : 'year-tab'; }
    get supYearClass2023() { return this.supYear === '2023' ? 'year-tab active' : 'year-tab'; }
    get supYearClass2024() { return this.supYear === '2024' ? 'year-tab active' : 'year-tab'; }
    get supYearClass2025() { return this.supYear === '2025' ? 'year-tab active' : 'year-tab'; }

    setSupYear(event) { this.supYear = event.currentTarget.dataset.year; }

    get supMonthlyBars() { return buildMonthlyBars((SUP_DATA[this.supYear] || SUP_DATA['2025']).monthly); }
    get supYoyBars()     { return buildYoyBars((SUP_DATA[this.supYear] || SUP_DATA['2025']).yoy); }
}