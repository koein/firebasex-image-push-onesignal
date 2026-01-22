import OSNotification from '../OSNotification';
export type OpenedEventActionType = 0 | 1;
export interface OpenedEvent {
    action: OpenedEventAction;
    notification: OSNotification;
}
export interface OpenedEventAction {
    actionId?: string;
    type: OpenedEventActionType;
}
