/*
    Custom day cell for the Transparent Calendar plasmoid.
    Based on org.kde.plasma.workspace.calendar's DayDelegate:
    - no highlight background for today/selected/hovered dates
    - orange bar shown below the date for today/selected dates
    - event dots shown below the date for dates that have events
    - faint hover tint as an affordance for the details panel
    - uses the Poppins font

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.workspace.calendar as PlasmaCalendar

PlasmaComponents.AbstractButton {
    id: dayStyle

    /*
     * Possible row types (not all used here):
     *
     * - year: ListModel
     *   * label: string
     *   * yearNumber: int
     *   * isCurrent: bool
     * - month: ListModel
     *   * label: string
     *   * monthNumber: int
     *   * yearNumber: int
     *   * isCurrent: bool
     * - day: PlasmaCalendar.DaysModel
     *   * no "label" role
     */
    required property int index
    required property var model

    // These two roles are defined for all row types. Other roles would have
    // to be fetched through the `model` row object.
    required property bool isCurrent
    required property int yearNumber

    required property int dateMatchingPrecision

    // Set by parent
    property date todayDate: new Date()
    // The currently selected date, or null when nothing is selected
    property var currentDate: null
    // Event titles for this date, e.g. ["Work sync", "Gym"]
    property var dayEvents: []

    readonly property date cellDate: thisDate

    property double mainLabelFontPixelSize: Math.max(
        Kirigami.Theme.defaultFont.pixelSize * 1.35 /* Level 1 Heading */,
        height / (dateMatchingPrecision === PlasmaCalendar.Calendar.MatchYearMonthAndDay ? 3 /* weeksColumn */ : 6))

    // Color of the bar below the highlighted date
    property string highlightBarColor: "#FF7E1F"

    // How many events can be shown as individual dots under the date
    property int maxEventDots: 3

    readonly property int eventDotSize: 4

    // Vertical position of the marker lane just below the centered date number.
    // The orange bar sits at this position, the event dots right below it.
    readonly property real markerY: {
        const ideal = height / 2 + mainLabelFontPixelSize / 2 + 3;
        const stackedHeight = 3 /* bar */ + 2 + eventDotSize;
        return Math.min(ideal, Math.max(0, height - stackedHeight - 1));
    }

    objectName: {
        switch (dateMatchingPrecision) {
        case PlasmaCalendar.Calendar.MatchYear:
            return "calendarCell-" + yearNumber;
        case PlasmaCalendar.Calendar.MatchYearAndMonth:
            return "calendarCell-" + yearNumber + "-" + model.monthNumber;
        case PlasmaCalendar.Calendar.MatchYearMonthAndDay:
        default:
            return "calendarCell-" + yearNumber + "-" + model.monthNumber + "-" + model.dayNumber;
        }
    }
    hoverEnabled: true
    enabled: isCurrent

    // type: either PlasmaCalendar.DaysModel or an equivalent ListModel
    required property QtObject dayModel

    readonly property date thisDate: {
        const monthNumber = (dateMatchingPrecision >= PlasmaCalendar.Calendar.MatchYearAndMonth) ? model.monthNumber - 1 : 0;
        const dayNumber = (dateMatchingPrecision >= PlasmaCalendar.Calendar.MatchYearMonthAndDay) ? model.dayNumber : 1;
        return new Date(yearNumber, monthNumber, dayNumber);
    }

    Accessible.name: thisDate.toLocaleDateString(Qt.locale(), Locale.LongFormat)

    readonly property bool today: {
        const today = todayDate;
        let result = true;
        if (dateMatchingPrecision >= PlasmaCalendar.Calendar.MatchYear) {
            result &= today.getFullYear() === thisDate.getFullYear();
        }
        if (dateMatchingPrecision >= PlasmaCalendar.Calendar.MatchYearAndMonth) {
            result &= today.getMonth() === thisDate.getMonth();
        }
        if (dateMatchingPrecision >= PlasmaCalendar.Calendar.MatchYearMonthAndDay) {
            result &= today.getDate() === thisDate.getDate();
        }
        return result;
    }
    readonly property bool selected: {
        const current = currentDate;
        if (!current) {
            return false;
        }
        let result = true;
        if (dateMatchingPrecision >= PlasmaCalendar.Calendar.MatchYear) {
            result &= current.getFullYear() === thisDate.getFullYear();
        }
        if (dateMatchingPrecision >= PlasmaCalendar.Calendar.MatchYearAndMonth) {
            result &= current.getMonth() === thisDate.getMonth();
        }
        if (dateMatchingPrecision >= PlasmaCalendar.Calendar.MatchYearMonthAndDay) {
            result &= current.getDate() === thisDate.getDate();
        }
        return result;
    }

    // Keyboard focus outline (backgrounds for today/selected/hover intentionally removed)
    Loader {
        anchors.fill: parent

        active: dayStyle.activeFocus
        asynchronous: true

        sourceComponent: KSvg.FrameSvgItem {
            anchors {
                leftMargin: -margins.left
                topMargin: -margins.top
                rightMargin: -margins.right
                bottomMargin: -margins.bottom
            }
            imagePath: "widgets/button"
            prefix: ["toolbutton-focus", "focus"]
        }
    }

    contentItem: Item {
        // ColumnLayout makes scrolling too slow, so use anchors to position labels

        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        PlasmaComponents.ToolTip.text: dayStyle.model.subLabel || ""
        PlasmaComponents.ToolTip.visible: !!dayStyle.model.subLabel && (Kirigami.Settings.isMobile ? dayStyle.pressed : dayStyle.hovered)

        // Barely-there tint on hover so the user can see which date is being previewed
        Rectangle {
            id: hoverTint

            anchors.fill: parent
            radius: Kirigami.Units.smallSpacing

            color: Kirigami.Theme.highlightColor
            opacity: dayStyle.hovered && dayStyle.enabled && !dayStyle.today && !dayStyle.selected ? 0.22 : 0

            Behavior on opacity {
                NumberAnimation {
                    easing.type: Easing.OutCubic
                    duration: Kirigami.Units.shortDuration
                }
            }
        }

        PlasmaComponents.Label {
            id: label
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            font.family: "Poppins"
            font.pixelSize: dayStyle.mainLabelFontPixelSize
            font.weight: dayStyle.dayEvents ? (dayStyle.dayEvents.length > 0 ? Font.DemiBold : Font.Normal) : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: dayStyle.model.label || dayStyle.model.dayLabel
            textFormat: Text.PlainText
            opacity: dayStyle.isCurrent ? 1.0 : 0.5
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }

        // Orange bar shown below the date for today and selected dates
        Rectangle {
            id: highlightBar

            readonly property bool active: dayStyle.today || dayStyle.selected

            anchors.horizontalCenter: parent.horizontalCenter
            y: dayStyle.markerY

            width: parent.width * 0.45
            height: 3
            radius: height / 2

            color: dayStyle.highlightBarColor
            opacity: active ? (dayStyle.today ? 1.0 : 0.7) : 0

            Behavior on opacity {
                NumberAnimation {
                    easing.type: Easing.OutCubic
                    duration: Kirigami.Units.shortDuration
                }
            }
        }

        // Event dots, shown below the date for dates that have events
        Row {
            id: eventDotsRow

            anchors.horizontalCenter: parent.horizontalCenter
            y: dayStyle.markerY + 3 /* bar height */ + 2
            spacing: 3

            Repeater {
                model: Math.min(dayStyle.dayEvents ? dayStyle.dayEvents.length : 0, dayStyle.maxEventDots)

                Rectangle {
                    required property int index

                    width: dayStyle.eventDotSize
                    height: dayStyle.eventDotSize
                    radius: dayStyle.eventDotSize / 2

                    color: dayStyle.highlightBarColor
                    opacity: 0.9
                }
            }
        }
    }
}
