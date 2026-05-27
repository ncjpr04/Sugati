import { LightningElement, api } from 'lwc';

/**
 * Maps country names (lowercase) to their corresponding flag emoji.
 * Used to display a flag icon alongside each destination in the list.
 */
const FLAG_MAP = {
    'maldives':'🇲🇻','kenya':'🇰🇪','tanzania':'🇹🇿','india':'🇮🇳',
    'sri lanka':'🇱🇰','bhutan':'🇧🇹','peru':'🇵🇪','argentina':'🇦🇷',
    'usa':'🇺🇸','united states':'🇺🇸','united kingdom':'🇬🇧','uk':'🇬🇧',
    'australia':'🇦🇺','new zealand':'🇳🇿','japan':'🇯🇵','south africa':'🇿🇦',
    'france':'🇫🇷','italy':'🇮🇹','spain':'🇪🇸','germany':'🇩🇪',
    'mexico':'🇲🇽','brazil':'🇧🇷','canada':'🇨🇦','switzerland':'🇨🇭',
    'thailand':'🇹🇭','greece':'🇬🇷','portugal':'🇵🇹','indonesia':'🇮🇩',
    'bali':'🇮🇩','vietnam':'🇻🇳','cambodia':'🇰🇭','nepal':'🇳🇵',
    'egypt':'🇪🇬','morocco':'🇲🇦','turkey':'🇹🇷','dubai':'🇦🇪',
    'uae':'🇦🇪','singapore':'🇸🇬','malaysia':'🇲🇾','oman':'🇴🇲',
    'jordan':'🇯🇴','iceland':'🇮🇸','costa rica':'🇨🇷','mauritius':'🇲🇺',
    'seychelles':'🇸🇨','madagascar':'🇲🇬','rwanda':'🇷🇼','botswana':'🇧🇼',
    'namibia':'🇳🇦','zimbabwe':'🇿🇼','zambia':'🇿🇲'
};

/**
 * Looks up the flag emoji for a given country name.
 * Performs a case-insensitive substring match against FLAG_MAP keys.
 * Uses Object.keys() to avoid iterating inherited properties.
 * @param {string} countryName - The name of the country to look up
 * @returns {string} Flag emoji if found, '📍' as fallback, '✈️' if name is empty
 */
function getFlag(countryName) {
    if (!countryName) {
        return '✈️';
    }
    const lowerCaseName = countryName.toLowerCase();
    for (const mapKey of Object.keys(FLAG_MAP)) {
        if (lowerCaseName.includes(mapKey)) {
            return FLAG_MAP[mapKey];
        }
    }
    return '📍';
}

/**
 * Top Destinations component for the Agency page.
 * Displays a scrollable list of travel destinations with booking count,
 * total nights and total revenue for the current year.
 * Data is pre-processed by Apex and passed in via @api destinations.
 */
export default class SugatiAgencyTopDestinations extends LightningElement {

    /** Pre-processed destination data from Apex getTopDestinations method */
    @api destinations   = [];

    /** Currency symbol derived from the first Supplier Booking record */
    @api currencySymbol = '£';

    currentYear = new Date().getFullYear();

    /**
     * Maps raw Apex DestinationItem wrappers into display-ready objects
     * for the template, including formatted strings for bookings, nights
     * and revenue.
     * @returns {Array} Array of display objects for the destination list
     */
    get topDestinations() {
        const symbol = this.currencySymbol || '£';
        return (this.destinations || []).map((destination, index) => {
            const bookingCount = destination.bookingCount || 0;
            const totalNights  = destination.totalNights  || 0;
            const totalRevenue = destination.totalRevenue || 0;
            return {
                id:             `dest-${index}`,
                name:           destination.country,
                flag:           getFlag(destination.country),
                bookingsString: `${bookingCount} booking${bookingCount !== 1 ? 's' : ''}`,
                nightsString:   `${totalNights} night${totalNights !== 1 ? 's' : ''}`,
                revString:      this.formatRevenue(totalRevenue, symbol)
            };
        });
    }

    /**
     * Formats a numeric revenue value into a human-readable string
     * with the appropriate currency symbol and K/M suffix.
     * @param {number} revenueValue         - The raw numeric revenue value
     * @param {string} currencySymbolToUse  - The currency symbol to prepend
     * @returns {string} Formatted revenue string e.g. '£284K', '£1.2M', '£750'
     */
    formatRevenue(revenueValue, currencySymbolToUse) {
        if (!revenueValue) {
            return `${currencySymbolToUse}0`;
        }
        if (revenueValue >= 1_000_000) {
            return `${currencySymbolToUse}${(revenueValue / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`;
        }
        if (revenueValue >= 1_000) {
            return `${currencySymbolToUse}${(revenueValue / 1_000).toFixed(1).replace(/\.0$/, '')}K`;
        }
        return `${currencySymbolToUse}${revenueValue.toLocaleString('en-GB', { maximumFractionDigits: 2 })}`;
    }

    /**
     * Returns true if there are destinations to display, false otherwise.
     * Used to toggle between the list and empty state in the template.
     * @returns {boolean}
     */
    get hasDestinations() {
        return this.topDestinations.length > 0;
    }
}