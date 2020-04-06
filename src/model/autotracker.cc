
// Copyright 2015 Toggl Desktop developers

#include "model/autotracker.h"

#include <Poco/UTF8String.h>

#include "const.h"

namespace toggl {

static const char kTermSeparator = '\t';

bool AutotrackerRule::Matches(const TimelineEvent &event) const {
    const Poco::LocalDateTime event_time(Poco::Timestamp::fromEpochTime(event.EndTime()));
    if (DaysOfWeek() != 0 && !std::bitset<7>(DaysOfWeek())[event_time.dayOfWeek()]) {
        logger().debug("Autotracker rule is not enabled on this weekday");
        return false;
    }
    if (!StartTime().empty()) {
        int h(0), m(0);
        if (toggl::Formatter::ParseTimeInput(StartTime(), &h, &m)) {
            Poco::LocalDateTime start(
                event_time.year(), event_time.month(), event_time.day(), h, m, event_time.second());
            if (event_time < start) {
                logger().debug("It's too early for this autotracker rule", " [", event_time.hour(), ":", event_time.minute(), "]", " (allowed from ", h, ":", m, ")");
                return false;
            }
        }
    }

    if (!EndTime().empty()) {
        int h(0), m(0);
        if (toggl::Formatter::ParseTimeInput(EndTime(), &h, &m)) {
            Poco::LocalDateTime end(
                event_time.year(), event_time.month(), event_time.day(), h, m, event_time.second());
            if (event_time > end) {
                logger().debug("It's too late for this autotracker rule", " [", event_time.hour(), ":", event_time.minute(), "]", " (allowed until ", h, ":", m, ")");
                return false;
            }
        }
    }

    for (const auto& term : Terms()) {
        if (Poco::UTF8::toLower(event.Title()).find(term)
                != std::string::npos) {
            return true;
        }
    }
    return false;
}

void AutotrackerRule::SetTerms(const std::string &value) {
    if (TermsString() != value) {
        Terms().clear();
        if (!value.empty()) {
            std::stringstream ss(value);
            while (ss.good()) {
                std::string tag;
                getline(ss, tag, kTermSeparator);
                Terms().push_back(tag);
            }
        }
        SetDirty();
}

void AutotrackerRule::SetPID(Poco::UInt64 value) {
    if (PID.Set(value))
        SetDirty();
}

void AutotrackerRule::SetTID(Poco::UInt64 value) {
    if (TID.Set(value))
        SetDirty();
}

std::string AutotrackerRule::String() const {
    std::stringstream ss;
    ss << " local_id=" << LocalID()
       << " terms=" << TermsString()
       << " uid=" << UID()
       << " pid=" << PID()
       << " tid=" << TID();
    return ss.str();
}

std::string AutotrackerRule::ModelName() const {
    return kModelAutotrackerRule;
}

std::string AutotrackerRule::ModelURL() const {
    return "";
}

const std::string AutotrackerRule::TermsString() const {
    std::stringstream ss;
    for (auto it = Terms().begin(); it != Terms().end(); ++it) {
        if (it != Terms().begin()) {
            ss << kTermSeparator;
        }
        ss << *it;
    }
    return ss.str();
}

void AutotrackerRule::SetDaysOfWeek(const Poco::UInt8 daysOfWeek) {
    if (DaysOfWeek.Set(daysOfWeek))
        SetDirty();
}

void AutotrackerRule::SetStartTime(const std::string &value) {
    if (StartTime.Set(value))
        SetDirty();
}

void AutotrackerRule::SetEndTime(const std::string &value) {
    if (EndTime.Set(value))
        SetDirty();
}

}  // namespace toggl
