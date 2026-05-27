import { LightningElement, api } from 'lwc';

/** Number of milliseconds in a single day — used for relative date calculation. */
const MILLISECONDS_PER_DAY = 86400000;

export default class SugatiAgencyRecentActivity extends LightningElement {

    /**
     * Recent Task records for this Supplier, passed from the parent component.
     * Expected fields: Id, Subject, TaskSubtype, sugati__Type__c, ActivityDate.
     */
    @api recentActivity;

    // ---- COMPUTED PROPERTIES ----

    /**
     * Maps raw Task sObjects into display-ready activity objects for the template.
     * Each activity has an icon, CSS class, type label and a relative date string.
     * @return {Array} Array of activity display objects.
     */
    get activities() {
        return (this.recentActivity || []).map(task => {
            const typeInfo = this.getTypeInfo(task.TaskSubtype || task.sugati__Type__c || '');
            return {
                key       : task.Id,
                icon      : typeInfo.icon,
                iconClass : `comm-icon ${typeInfo.cssClass}`,
                title     : task.Subject || 'No Subject',
                meta      : `${typeInfo.label}${task.ActivityDate
                    ? ' · ' + this.formatRelativeDate(task.ActivityDate)
                    : ''}`
            };
        });
    }

    /**
     * Returns true when there is at least one activity to display.
     * Used by the template to toggle between the list and the empty state.
     * @return {Boolean}
     */
    get hasActivities() {
        return this.activities.length > 0;
    }

    /**
     * Returns the total count of activity records.
     * Displayed in the card header alongside the title.
     * @return {Number}
     */
    get taskCount() {
        return this.activities.length;
    }

    // ---- PRIVATE HELPERS ----

    /**
     * Determines the icon, CSS class and label for a given task type string.
     * Performs case-insensitive substring matching against known type keywords.
     * Defaults to a generic task icon when no keyword matches.
     * @param  {String} taskTypeRaw - Raw TaskSubtype or custom type field value.
     * @return {{ icon: String, cssClass: String, label: String }}
     */
    getTypeInfo(taskTypeRaw) {
        const lowerCaseType = (taskTypeRaw || '').toLowerCase();

        if (lowerCaseType.includes('call') || lowerCaseType.includes('phone')) {
            return { icon: '📞', cssClass: 'comm-phone', label: 'Call' };
        }
        if (lowerCaseType.includes('email')) {
            return { icon: '✉', cssClass: 'comm-email', label: 'Email' };
        }
        if (lowerCaseType.includes('meet')) {
            return { icon: '👥', cssClass: 'comm-meet', label: 'Meeting' };
        }
        return { icon: '📝', cssClass: 'comm-note', label: 'Task' };
    }

    /**
     * Formats a date string as a human-readable relative label.
     * Returns 'Today', 'Yesterday', 'N days ago', '1 week ago',
     * 'N weeks ago', or a short month/year string for older dates.
     * Returns '—' when no date is supplied.
     * @param  {String|null} dateString - ISO date string from the ActivityDate field.
     * @return {String} Human-readable relative date label.
     */
    formatRelativeDate(dateString) {
        if (!dateString) {
            return '—';
        }

        const daysDifference = Math.floor(
            (Date.now() - new Date(dateString)) / MILLISECONDS_PER_DAY
        );

        if (daysDifference === 0)  { return 'Today'; }
        if (daysDifference === 1)  { return 'Yesterday'; }
        if (daysDifference < 7)    { return `${daysDifference} days ago`; }
        if (daysDifference < 14)   { return '1 week ago'; }
        if (daysDifference < 30)   { return `${Math.floor(daysDifference / 7)} weeks ago`; }

        return new Date(dateString).toLocaleDateString('en-GB', {
            month : 'short',
            year  : 'numeric'
        });
    }
}