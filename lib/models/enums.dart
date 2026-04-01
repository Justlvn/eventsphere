enum GlobalRole { admin, student }

enum AssociationRole { responsible, member }

enum EventVisibility { public, restricted, private }

enum EventCategory { soiree, afterwork, journee, venteNourriture, sport, culture, concert }

extension GlobalRoleExtension on GlobalRole {
  String get value {
    switch (this) {
      case GlobalRole.admin:
        return 'admin';
      case GlobalRole.student:
        return 'student';
    }
  }

  static GlobalRole fromString(String value) {
    switch (value) {
      case 'admin':
        return GlobalRole.admin;
      default:
        return GlobalRole.student;
    }
  }
}

extension AssociationRoleExtension on AssociationRole {
  String get value {
    switch (this) {
      case AssociationRole.responsible:
        return 'responsible';
      case AssociationRole.member:
        return 'member';
    }
  }

  static AssociationRole fromString(String value) {
    switch (value) {
      case 'responsible':
        return AssociationRole.responsible;
      default:
        return AssociationRole.member;
    }
  }
}

extension EventCategoryExtension on EventCategory {
  String get value {
    switch (this) {
      case EventCategory.soiree:
        return 'soiree';
      case EventCategory.afterwork:
        return 'afterwork';
      case EventCategory.journee:
        return 'journee';
      case EventCategory.venteNourriture:
        return 'vente_nourriture';
      case EventCategory.sport:
        return 'sport';
      case EventCategory.culture:
        return 'culture';
      case EventCategory.concert:
        return 'concert';
    }
  }

  String get label {
    switch (this) {
      case EventCategory.soiree:
        return 'Soirée';
      case EventCategory.afterwork:
        return 'Afterwork';
      case EventCategory.journee:
        return 'Journée';
      case EventCategory.venteNourriture:
        return 'Vente de nourriture';
      case EventCategory.sport:
        return 'Sport';
      case EventCategory.culture:
        return 'Culture';
      case EventCategory.concert:
        return 'Concert';
    }
  }

  static EventCategory fromString(String value) {
    switch (value) {
      case 'soiree':
        return EventCategory.soiree;
      case 'afterwork':
        return EventCategory.afterwork;
      case 'journee':
        return EventCategory.journee;
      case 'vente_nourriture':
        return EventCategory.venteNourriture;
      case 'sport':
        return EventCategory.sport;
      case 'culture':
        return EventCategory.culture;
      case 'concert':
        return EventCategory.concert;
      // Fallback pour les anciennes valeurs en base
      case 'atelier':
      case 'autre':
      default:
        return EventCategory.soiree;
    }
  }
}

extension EventVisibilityExtension on EventVisibility {
  String get value {
    switch (this) {
      case EventVisibility.public:
        return 'public';
      case EventVisibility.restricted:
        return 'restricted';
      case EventVisibility.private:
        return 'private';
    }
  }

  String get label {
    switch (this) {
      case EventVisibility.public:
        return 'Public';
      case EventVisibility.restricted:
        return 'Restreint';
      case EventVisibility.private:
        return 'Privé';
    }
  }

  String get description {
    switch (this) {
      case EventVisibility.public:
        return 'Visible par tout le monde';
      case EventVisibility.restricted:
        return 'Membres et responsables uniquement';
      case EventVisibility.private:
        return 'Tous les responsables (toutes associations)';
    }
  }

  static EventVisibility fromString(String value) {
    switch (value) {
      case 'private':
        return EventVisibility.private;
      case 'restricted':
        return EventVisibility.restricted;
      default:
        return EventVisibility.public;
    }
  }
}
