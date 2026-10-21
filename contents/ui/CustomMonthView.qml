/*
    Custom month-only calendar view for the Transparent Calendar plasmoid.
    Based on org.kde.plasma.workspace.calendar's MonthView:
    - no Days/Months/Years view switcher (always shows the day/month grid)
    - keeps month/year heading with previous/today/next navigation
    - uses custom day delegates (Poppins font, orange bar, no date background)
    - events: hovering a date with events opens a floating details card at the
      bottom; clicking a date selects it and opens the card with an add-event
      field; events appear as dots under the date

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.workspace.calendar as PlasmaCalendar

Item {
    id: root

    // Accept keyboard focus so Escape can close the details panel even when
    // no child (grid cell, text field, ...) currently has focus.
    focus: true

    Keys.onEscapePressed: root.closeAndDeselect()

    /**
     * The date considered "today".
     */
    property alias today: calendarBackend.today
    /**
     * Whether to show a week numbers column.
     */
    property bool showWeekNumbers: false
    /**
     * The currently selected date, or null when nothing is selected.
     */
    property var currentDate: null

    property int borderWidth: 1

    /**
     * Events as a plain JS object mapping "yyyy-MM-dd" to an array of titles, e.g.:
     * { "2026-10-22": ["Work sync", "Gym"] }
     *
     * The view never mutates this in place; it always assigns a new object and
     * the parent applet persists it via the `events` change signal.
     */
    property var events: ({})

    /**
     * The event plugins manager used in the view (used as in upstream MonthView;
     * left unset in this applet, but kept for API compatibility).
     */
    property PlasmaCalendar.EventPluginsManager eventPluginsManager

    readonly property int columns: calendarBackend.days
    readonly property int rows: calendarBackend.weeks

    readonly property string displayedMonthName: Qt.locale(Qt.locale().uiLanguages[0]).standaloneMonthName(calendarBackend.displayedDate.getMonth(), Locale.LongFormat)
    readonly property int displayedYear: calendarBackend.displayedDate.getFullYear()

    // The date currently shown by the hover preview (latched while the pointer
    // stays inside the view so the card does not flicker), or null.
    property var previewDate: null
    // Whether a date has been clicked/selected (the card is "owned" by it)
    property bool addPanelOpen: false
    // Set right after closing/deselecting so a still-hovered cell with events
    // does not immediately re-open the preview. Reset when the pointer leaves.
    property bool suppressHover: false

    // Whether the pointer is anywhere inside this view (grid, header or card)
    readonly property bool pointerInsideView: viewHover.hovered

    readonly property bool panelVisible:
        root.addPanelOpen
        || (root.pointerInsideView && root.previewDate !== null && !root.suppressHover)

    /**
     * The date the details card is showing: the selected date when one is
     * selected, otherwise the hover-preview date.
     */
    readonly property var detailsDate: root.addPanelOpen ? root.currentDate : root.previewDate

    // The add field is only shown for the selected (clicked) date
    readonly property bool showAddEventField: root.addPanelOpen

    function showPreviousMonth() {
        calendarBackend.previousMonth();
    }

    function showNextMonth() {
        calendarBackend.nextMonth();
    }

    function showToday() {
        calendarBackend.resetToToday();
    }

    function resetHoverState() {
        root.previewDate = null;
        root.addPanelOpen = false;
        root.currentDate = null;
        root.suppressHover = false;
    }

    // Close the details card and clear the date selection
    function closeAndDeselect() {
        root.addPanelOpen = false;
        root.currentDate = null;
        root.previewDate = null;
        root.suppressHover = true;
    }

    function focusAddField() {
        if (root.showAddEventField) {
            addEventField.forceActiveFocus();
        }
    }

    function eventDateKey(date) {
        if (!date || isNaN(date.getTime())) {
            return "";
        }
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    function eventsForDate(date) {
        const list = root.events[root.eventDateKey(date)];
        return Array.isArray(list) ? list : [];
    }

    function addEvent(eventDate, title) {
        const trimmed = ("" + title).trim();
        if (trimmed.length === 0) {
            return;
        }

        const key = root.eventDateKey(eventDate);
        const next = JSON.parse(JSON.stringify(root.events));
        (next[key] = next[key] || []).push(trimmed);

        root.events = next;
    }

    function removeEvent(eventDate, index) {
        const key = root.eventDateKey(eventDate);
        const next = JSON.parse(JSON.stringify(root.events));
        if (!Array.isArray(next[key]) || index < 0 || index >= next[key].length) {
            return;
        }

        next[key].splice(index, 1);
        if (next[key].length === 0) {
            delete next[key];
        }

        root.events = next;
    }

    PlasmaCalendar.Calendar {
        id: calendarBackend

        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: root.today

        Component.onCompleted: {
            daysModel.setPluginsManager(root.eventPluginsManager);
        }
    }

    // Tracks whether the pointer is anywhere over this view (grid + header + card)
    HoverHandler {
        id: viewHover
    }

    Connections {
        target: viewHover
        function onHoveredChanged() {
            if (!viewHover.hovered) {
                // Pointer left the widget: drop the preview and allow it again
                root.previewDate = null;
                root.suppressHover = false;
            }
        }
    }

    // Focuses the add-event field after the card has opened (deferred one tick
    // so the field is already visible when focus is requested).
    Timer {
        id: focusTimer
        interval: 0
        onTriggered: root.focusAddField()
    }

    /* ------------------------------------------------------- UI Starts From Here ----------------------------------------------------- */

    RowLayout {
        id: viewHeader

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: Kirigami.Units.smallSpacing
        }
        spacing: 0

        Kirigami.Heading {
            id: heading

            text: root.displayedYear === new Date().getFullYear()
                ? root.displayedMonthName
                : root.displayedMonthName + " " + root.displayedYear
            textFormat: Text.PlainText
            level: 2
            elide: Text.ElideRight
            font.family: "Poppins"
            font.capitalization: Font.Capitalize
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }

        PlasmaComponents.ToolButton {
            id: previousButton

            text: "Previous Month"
            icon.name: Qt.application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
            display: T.AbstractButton.IconOnly

            onClicked: root.showPreviousMonth()

            PlasmaComponents.ToolTip { text: parent.text }
        }

        PlasmaComponents.ToolButton {
            id: todayButton

            text: "Today"

            onClicked: root.showToday()

            PlasmaComponents.ToolTip { text: parent.text }
        }

        PlasmaComponents.ToolButton {
            id: nextButton

            text: "Next Month"
            icon.name: Qt.application.layoutDirection === Qt.RightToLeft ? "go-previous" : "go-next"
            display: T.AbstractButton.IconOnly

            onClicked: root.showNextMonth()

            PlasmaComponents.ToolTip { text: parent.text }
        }
    }

    Item {
        id: gridArea

        anchors {
            top: viewHeader.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: Kirigami.Units.smallSpacing
            bottomMargin: Kirigami.Units.smallSpacing
        }

        // Take the calendar width, subtract the inner and outer spacings and divide by number of columns (==days in week)
        readonly property int cellWidth: Math.floor((gridArea.width - (root.columns + 1) * root.borderWidth) / (root.columns + (root.showWeekNumbers ? 1 : 0)))
        // Take the calendar height, subtract the inner spacings and divide by number of rows (root.weeks + one row for day names)
        readonly property int cellHeight: Math.floor((gridArea.height - (root.rows + 1) * root.borderWidth) / (root.rows + 1))

        // Week numbers column
        Column {
            visible: root.showWeekNumbers
            anchors {
                top: parent.top
                left: parent.left
                bottom: parent.bottom
                // The borderWidth needs to be counted twice here because it goes
                // in fact through two lines - the topmost one (the outer edge)
                // and then the one below weekday strings
                topMargin: gridArea.cellHeight + root.borderWidth + root.borderWidth
            }
            spacing: root.borderWidth

            Repeater {
                model: root.showWeekNumbers ? calendarBackend.weeksModel : null

                PlasmaComponents.Label {
                    required property int modelData

                    width: gridArea.cellWidth
                    height: gridArea.cellHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    textFormat: Text.PlainText
                    font.family: "Poppins"
                    font.italic: true
                    opacity: 0.75
                }
            }
        }

        Grid {
            id: calendarGrid

            anchors {
                top: parent.top
                right: parent.right
                rightMargin: root.borderWidth
                bottom: parent.bottom
                bottomMargin: root.borderWidth
            }

            columns: root.columns
            rows: root.rows + 1

            spacing: root.borderWidth

            Repeater {
                id: dayOfWeekHeaderRepeater

                PlasmaComponents.Label {
                    id: dayOfWeekLabel

                    required property int index

                    width: gridArea.cellWidth
                    height: gridArea.cellHeight
                    text: Qt.locale(Qt.locale().uiLanguages[0]).dayName(((calendarBackend.firstDayOfWeek + index) % dayOfWeekHeaderRepeater.count), Locale.ShortFormat)
                    textFormat: Text.PlainText
                    font.family: "Poppins"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    opacity: 0.75
                    fontSizeMode: Text.HorizontalFit
                }
            }

            Repeater {
                id: gridRepeater

                model: calendarBackend.daysModel

                CustomDayDelegate {
                    id: dayDelegate

                    width: gridArea.cellWidth
                    height: gridArea.cellHeight
                    dayModel: calendarBackend.daysModel
                    dateMatchingPrecision: PlasmaCalendar.Calendar.MatchYearMonthAndDay
                    todayDate: root.today
                    currentDate: root.currentDate
                    dayEvents: root.eventsForDate(dayDelegate.cellDate)

                    // Hovering a date with events starts/updates the preview.
                    // The preview date is latched (see previewDate) so the card
                    // stays open while the pointer moves around — no flicker.
                    onHoveredChanged: {
                        if (dayDelegate.hovered
                            && root.eventsForDate(dayDelegate.cellDate).length > 0) {
                            root.previewDate = dayDelegate.cellDate;
                        }
                    }

                    // Clicking a date selects it and opens the add-event card;
                    // clicking the selected date again deselects it and closes
                    onClicked: {
                        if (root.currentDate !== null
                            && root.currentDate.getTime() === dayDelegate.cellDate.getTime()) {
                            root.closeAndDeselect();
                        } else {
                            root.currentDate = dayDelegate.cellDate
                            root.previewDate = null;
                            root.addPanelOpen = true;
                            root.suppressHover = false;
                            root.focusTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // Floating details card anchored to the bottom, overlaying the grid.
    // It has a fixed generous height (so the grid never resizes — no flicker)
    // and generous internal margins.
    Item {
        id: detailsPanel

        z: 10

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: Kirigami.Units.largeSpacing
            rightMargin: Kirigami.Units.largeSpacing
            bottomMargin: Kirigami.Units.largeSpacing
        }

        readonly property real expandedHeight: Math.min(Kirigami.Units.gridUnit * 7, root.height * 0.55)

        readonly property var panelEvents: root.panelVisible ? root.eventsForDate(root.detailsDate) : []

        height: root.panelVisible ? expandedHeight : 0
        visible: root.panelVisible || height > 0
        clip: true

        Behavior on height {
            NumberAnimation {
                easing.type: Easing.OutCubic
                duration: Kirigami.Units.shortDuration
            }
        }

        // Card background
        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.largeSpacing
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Kirigami.Theme.highlightColor
            opacity: 0.97
        }

        ColumnLayout {
            id: panelBody

            anchors {
                fill: parent
                margins: Kirigami.Units.largeSpacing
            }
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                spacing: 0

                PlasmaComponents.Label {
                    text: root.detailsDate ? Qt.formatDate(root.detailsDate, Qt.locale(), "dddd, d MMMM yyyy") : ""
                    textFormat: Text.PlainText
                    font.family: "Poppins"
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                PlasmaComponents.ToolButton {
                    id: closePanelButton

                    visible: root.addPanelOpen
                    icon.name: "window-close"
                    display: T.AbstractButton.IconOnly
                    text: "Close"

                    onClicked: root.closeAndDeselect()

                    PlasmaComponents.ToolTip { text: parent.text }
                }
            }

            ListView {
                id: eventList

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                QQC2.ScrollBar.vertical: QQC2.ScrollBar { }

                model: detailsPanel.panelEvents

                // Keep the newest entries visible when the list overflows
                onCountChanged: {
                    positionViewAtEnd();
                }

                delegate: Item {
                    id: eventRow

                    required property int index
                    required property string modelData

                    width: eventList.width
                    height: Kirigami.Units.iconSizes.sizeForLabels

                    // HoverHandler stays "hovered" even while over the delete
                    // button (unlike MouseArea.containsMouse, which the button
                    // occludes and causes the delete button to flicker).
                    HoverHandler {
                        id: eventRowHover
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.smallSpacing

                        // Bullet to match the dots on the grid
                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: "#FF7E1F"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        PlasmaComponents.Label {
                            text: eventRow.modelData
                            textFormat: Text.PlainText
                            font.family: "Poppins"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        PlasmaComponents.ToolButton {
                            id: deleteEventButton

                            visible: eventRowHover.hovered
                            icon.name: "edit-delete"
                            display: T.AbstractButton.IconOnly
                            text: "Remove event"

                            onClicked: root.removeEvent(root.detailsDate, eventRow.index)

                            PlasmaComponents.ToolTip { text: parent.text }
                        }
                    }
                }
            }

            RowLayout {
                visible: root.showAddEventField

                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.TextField {
                    id: addEventField

                    placeholderText: "Add event…"
                    clearButtonShown: false
                    font.family: "Poppins"
                    Layout.fillWidth: true

                    // Escape closes the panel while typing
                    Keys.onEscapePressed: root.closeAndDeselect()

                    onAccepted: {
                        root.addEvent(root.detailsDate, text);
                        clear();
                    }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "list-add"
                    display: T.AbstractButton.IconOnly
                    text: "Add event"
                    visible: addEventField.length > 0 && root.showAddEventField

                    onClicked: {
                        root.addEvent(root.detailsDate, addEventField.text);
                        addEventField.clear();
                    }

                    PlasmaComponents.ToolTip { text: parent.text }
                }
            }
        }
    }
}
