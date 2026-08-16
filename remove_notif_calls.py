import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Completely remove _notifyOwnerNewOrder definition
content = re.sub(r"/// ═══ إرسال إشعار OneSignal لصاحب المطعم عند طلب جديد ═══.*?\n  \}\n\n", "", content, flags=re.DOTALL)

# Completely remove _notifyCustomer definition
content = re.sub(r"/// ═══ إرسال إشعار OneSignal للزبون عند تغيير حالة طلبه ═══.*?\n  \}\n\n", "", content, flags=re.DOTALL)

# Completely remove _notifyAllDrivers definition
content = re.sub(r"/// ═══ إرسال إشعار لجميع المندوبين المسجلين في مطعم معين ═══.*?\n  \}\n\n", "", content, flags=re.DOTALL)

# Remove all calls to _notifyOwnerNewOrder
content = re.sub(r"await _notifyOwnerNewOrder\([\s\S]*?\);", "", content)

# Remove all calls to _notifyCustomer
content = re.sub(r"await _notifyCustomer\([\s\S]*?\);", "", content)

# Remove all calls to _notifyAllDrivers
content = re.sub(r"await _notifyAllDrivers\([\s\S]*?\);", "", content)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('done replacing calls')
