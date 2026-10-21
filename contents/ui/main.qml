/*
    SPDX-FileCopyrightText: 2013 Heena Mahour <heena393@gmail.com>
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick 2.12
import QtQuick.Layouts 1.12

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 12

    // Don't let the containment paint an opaque frame behind the widget.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    toolTipMainText: Qt.formatDate(dataSource.data.Local.DateTime, "dddd")
    toolTipSubText: {
        // this logic is taken from digital-clock:
        // remove "dddd" from the locale format string
        // /all/ locales in LongFormat have "dddd" either
        // at the beginning or at the end. so we just
        // remove it + the delimiter and space
        var format = Qt.locale().dateFormat(Locale.LongFormat);
        format = format.replace(/(^dddd.?\s)|(,?\sdddd$)/, "");
        return Qt.formatDate(dataSource.data.Local.DateTime, format)
    }

    Layout.minimumWidth: Kirigami.Units.iconSizes.large
    Layout.minimumHeight: Kirigami.Units.iconSizes.large

    // ---- Event storage ------------------------------------------------------
    //
    // Events are kept as a JSON string in the plasmoid configuration (key
    // "events"): { "2026-10-22": ["Work sync", "Gym"], ... }
    //
    // Events older than KEEP_DAYS are pruned on every save so the string stays
    // small. The view never edits the object in place; it signals eventsChanged
    // whenever the calendar makes a modification.

    // How long past events are kept around
    readonly property int preserveDays: 90

    property var calendarEvents: ({})

    Component.onCompleted: {
        root.calendarEvents = root.loadEvents();
    }

    function loadEvents() {
        try {
            const parsed = JSON.parse(Plasmoid.configuration.events || "{}");
            return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : {};
        } catch (e) {
            console.warn("Ougi Calendar: could not parse events config, resetting.", e);
            return {};
        }
    }

    function saveEvents(events) {
        const today = new Date();
        const cutoff = new Date(today.getFullYear(), today.getMonth(), today.getDate() - root.preserveDays, 23, 59, 59);

        let pruned = {};
        let changed = false;

        for (const key in events) {
            if (!Array.isArray(events[key]) || events[key].length === 0) {
                changed = true;
                continue;
            }
            const eventDate = new Date(key); // "yyyy-MM-dd"
            if (isNaN(eventDate.getTime()) || eventDate < cutoff) {
                changed = true;
                continue;
            }
            pruned[key] = events[key];
        }

        if (changed) {
            pruned = JSON.parse(JSON.stringify(pruned));
            root.calendarEvents = pruned;
        }

        Plasmoid.configuration.events = JSON.stringify(pruned);
    }
    // --------------------------------------------------------------------------

    // Reset the panel + hover state whenever the popup is closed
    Connections {
        target: root
        function onExpandedChanged() {
            if (!root.expanded) {
                calendar.resetHoverState();
            }
        }
    }

    P5Support.DataSource {
        id: dataSource
        engine: "time"
        connectedSources: ["Local"]
        interval: 60000
        intervalAlignment: P5Support.Types.AlignToMinute
    }

    // Only exists because the default CompactRepresentation doesn't expose a
    // generic way to overlay something on top of the icon.
    // TODO remove once it gains that feature.
    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded

        // Icon drawn in QML instead of using the mini-calendar SVG so that the
        // background stays transparent and the outline follows the theme colors.
        Rectangle {
            id: calendarIcon
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.roundedIconSize(Math.min(parent.width, parent.height))
            height: width

            color: "transparent"
            radius: width * 0.16
            border.width: Math.max(1, Math.round(width * 0.035))
            border.color: Kirigami.Theme.textColor

            readonly property real contentMargin: Math.max(1, Math.round(width * 0.1))

            Rectangle {
                id: headerRule
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: parent.height * 0.3
                }
                height: Math.max(1, Math.round(parent.height * 0.035))
                color: Kirigami.Theme.textColor
            }

            PlasmaComponents3.Label {
                id: monthLabel
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: headerRule.top
                    margins: calendarIcon.contentMargin
                }

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.Fit
                minimumPointSize: 1

                color: Kirigami.Theme.textColor

                text: {
                    var d = new Date(dataSource.data.Local.DateTime);
                    return Qt.formatDate(d, "MMM");
                }
                textFormat: Text.PlainText
                visible: calendarIcon.width > Kirigami.Units.gridUnit * 3
            }

            PlasmaComponents3.Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: headerRule.bottom
                    bottom: parent.bottom
                    leftMargin: calendarIcon.contentMargin
                    rightMargin: calendarIcon.contentMargin
                    bottomMargin: calendarIcon.contentMargin
                }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                minimumPointSize: 1
                font.pixelSize: 1000
                font.weight: Font.Bold

                fontSizeMode: Text.Fit

                color: Kirigami.Theme.textColor
                text: {
                    var d = new Date(dataSource.data.Local.DateTime)
                    var format = Plasmoid.configuration.compactDisplay

                    if (format === "w") {
                        return Plasmoid.weekNumber(d)
                    }

                    return Qt.formatDate(d, format)
                }
                textFormat: Text.PlainText
            }
        }
    }

    fullRepresentation: Item {

        // sizing taken from digital clock
        readonly property int _minimumWidth: calendar.showWeekNumbers ? Math.round(_minimumHeight * 1.75) : Math.round(_minimumHeight * 1.5)
        readonly property int _minimumHeight: Kirigami.Units.gridUnit * 14
        readonly property var appletInterface: root

        Layout.minimumWidth: _minimumWidth
        Layout.maximumWidth: Kirigami.Units.gridUnit * 80
        Layout.minimumHeight: _minimumHeight
        Layout.maximumHeight: Kirigami.Units.gridUnit * 40

        // Custom month-only calendar: no Days/Months/Years switcher, Poppins
        // font, orange bar below the date instead of a background highlight.
        CustomMonthView {
            id: calendar
            today: dataSource.data["Local"]["DateTime"]
            showWeekNumbers: Plasmoid.configuration.showWeekNumbers
            events: root.calendarEvents

            // Persist every calendar event change (add/remove) into the config
            onEventsChanged: root.saveEvents(calendar.events)

            anchors.fill: parent
        }
    }
}
