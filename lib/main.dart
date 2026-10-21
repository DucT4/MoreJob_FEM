import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'web_portal.dart';

void main() => runApp(const MoreJobApp());

final api = MoreJobApi();

class MoreJobApp extends StatefulWidget {
  const MoreJobApp({super.key});
  @override
  State<MoreJobApp> createState() => _MoreJobAppState();
}

class _MoreJobAppState extends State<MoreJobApp> {
  late Future<bool> session = api.restore();
  void changed() => setState(() => session = Future.value(api.user != null));
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'More Job IL',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146B63)),
      useMaterial3: true,
    ),
    home: FutureBuilder<bool>(
      future: session,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!
            ? HomePage(onLogout: changed)
            : AuthPage(onLogin: changed);
      },
    ),
  );
}

void showError(BuildContext context, Object error) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onLogin});
  final VoidCallback onLogin;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!email.text.contains('@') ||
        password.text.length < 6 ||
        (register && name.text.trim().isEmpty)) {
      showError(context, 'Kiểm tra họ tên, email và mật khẩu ít nhất 6 ký tự.');
      return;
    }
    setState(() => busy = true);
    try {
      if (register) {
        await api.register(name.text.trim(), email.text.trim(), password.text);
      } else {
        await api.login(email.text.trim(), password.text);
      }
      widget.onLogin();
    } catch (error) {
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.work_outline,
                    size: 64,
                    color: Color(0xFF146B63),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'More Job IL',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 28),
                  if (register)
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Họ tên'),
                    ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      register ? 'Tạo tài khoản sinh viên' : 'Đăng nhập',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => register = !register),
                    child: Text(
                      register
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WebPortalHub()),
                    ),
                    icon: const Icon(Icons.public),
                    label: const Text('Khám phá tính năng web'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('More Job IL'),
      actions: [
        IconButton(
          tooltip: 'Tất cả tính năng web',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WebPortalHub()),
          ),
          icon: const Icon(Icons.public),
        ),
      ],
    ),
    body: IndexedStack(
      index: tab,
      children: [
        JobsPage(active: tab == 0),
        SavedPage(active: tab == 1),
        ApplicationsPage(active: tab == 2),
        ProfilePage(active: tab == 3, onLogout: widget.onLogout),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (index) => setState(() => tab = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.search), label: 'Tìm việc'),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          label: 'Đã lưu',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          label: 'Đơn ứng tuyển',
        ),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'Hồ sơ'),
      ],
    ),
  );
}

List<Map<String, dynamic>> pageItems(dynamic data) => (data['content'] as List)
    .map((item) => Map<String, dynamic>.from(item as Map))
    .toList();

class JobsPage extends StatefulWidget {
  const JobsPage({super.key, required this.active});
  final bool active;
  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final keyword = TextEditingController();
  final location = TextEditingController();
  int page = 0;
  late Future<dynamic> result = load();
  Future<dynamic> load() => api.get(
    '/jobs',
    query: {
      'page': '$page',
      'size': '10',
      'keyword': keyword.text.trim(),
      'location': location.text.trim(),
    },
  );
  void refresh() => setState(() => result = load());
  @override
  void dispose() {
    keyword.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: keyword,
                decoration: const InputDecoration(
                  labelText: 'Từ khóa',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Địa điểm'),
              ),
            ),
            IconButton(
              onPressed: () {
                page = 0;
                refresh();
              },
              icon: const Icon(Icons.tune),
              tooltip: 'Lọc',
            ),
          ],
        ),
      ),
      Expanded(
        child: DataList(
          result: result,
          builder: (items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => JobCard(
              job: items[index],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobDetailPage(id: items[index]['id'] as int),
                ),
              ),
            ),
          ),
        ),
      ),
      FutureBuilder<dynamic>(
        future: result,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final data = snapshot.data as Map<String, dynamic>;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: page > 0
                    ? () {
                        page--;
                        refresh();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Trang ${page + 1} / ${data['totalPages']}'),
              IconButton(
                onPressed: data['last'] == false
                    ? () {
                        page++;
                        refresh();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class DataList extends StatelessWidget {
  const DataList({super.key, required this.result, required this.builder});
  final Future<dynamic> result;
  final Widget Function(List<Map<String, dynamic>>) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
        );
      }
      final items = pageItems(snapshot.data);
      if (items.isEmpty) return const Center(child: Text('Chưa có dữ liệu.'));
      return builder(items);
    },
  );
}

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: ListTile(
      title: Text('${job['title'] ?? ''}'),
      subtitle: Text(
        '${job['location'] ?? ''} · ${job['salaryLabel'] ?? 'Thỏa thuận'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({super.key, required this.id});
  final int id;
  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  late final Future<dynamic> detail = api.get('/jobs/${widget.id}');
  Future<void> save() async {
    try {
      await api.post('/students/me/saved-jobs', {'jobId': widget.id});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã lưu việc làm.')));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết việc làm')),
    body: FutureBuilder<dynamic>(
      future: detail,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Text(
              snapshot.hasError ? snapshot.error.toString() : 'Đang tải...',
            ),
          );
        }
        final job = snapshot.data as Map<String, dynamic>;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${job['title']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${job['companyName'] ?? ''} · ${job['location'] ?? ''}'),
            const SizedBox(height: 12),
            Text('${job['salaryLabel'] ?? 'Thỏa thuận'}'),
            const SizedBox(height: 20),
            Text('${job['description'] ?? ''}'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Lưu tin'),
            ),
            FilledButton(
              onPressed: job['isFull'] == true
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ApplyPage(job: job)),
                    ),
              child: const Text('Ứng tuyển'),
            ),
          ],
        );
      },
    ),
  );
}

class SavedPage extends StatefulWidget {
  const SavedPage({super.key, required this.active});
  final bool active;
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  int page = 0;
  late Future<dynamic> result = load();
  Future<dynamic> load() => api.get(
    '/students/me/saved-jobs',
    query: {'page': '$page', 'size': '10'},
  );
  @override
  void didUpdateWidget(SavedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) setState(() => result = load());
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: DataList(
          result: result,
          builder: (items) => ListView(
            children: items.map((entry) {
              final job = Map<String, dynamic>.from(entry['job'] as Map);
              return Dismissible(
                key: ValueKey(entry['id']),
                background: Container(
                  color: Colors.red.shade100,
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete),
                ),
                onDismissed: (_) async {
                  try {
                    await api.delete(
                      '/students/me/saved-jobs/${entry['jobId']}',
                    );
                  } catch (error) {
                    if (context.mounted) showError(context, error);
                  }
                },
                child: JobCard(
                  job: job,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobDetailPage(id: entry['jobId'] as int),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      PageControls(
        result: result,
        page: page,
        previous: page > 0
            ? () => setState(() {
                page--;
                result = load();
              })
            : null,
        next: () => setState(() {
          page++;
          result = load();
        }),
      ),
    ],
  );
}

class ApplyPage extends StatefulWidget {
  const ApplyPage({super.key, required this.job});
  final Map<String, dynamic> job;
  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  final cover = TextEditingController();
  int? artifactId;
  String? cvTitle;
  bool busy = false;
  late Future<dynamic> cvs = api.get('/students/me/cvs');
  @override
  void dispose() {
    cover.dispose();
    super.dispose();
  }

  Future<void> pickCv() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (picked == null) return;
    setState(() => busy = true);
    try {
      final file = picked;
      final id = await api.uploadCv(file, file.name);
      setState(() {
        artifactId = id;
        cvTitle = file.name;
        cvs = api.get('/students/me/cvs');
      });
    } catch (error) {
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> apply() async {
    if (artifactId == null) {
      showError(context, 'Chọn hoặc tải CV PDF trước khi ứng tuyển.');
      return;
    }
    setState(() => busy = true);
    try {
      await api.post('/students/me/applications', {
        'jobId': widget.job['id'],
        'cvArtifactId': artifactId,
        'coverLetter': cover.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ứng tuyển thành công.')));
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ứng tuyển')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${widget.job['title']}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        FutureBuilder<dynamic>(
          future: cvs,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final items = pageItems(snapshot.data)
                .where(
                  (cv) =>
                      cv['latestArtifactStatus'] == 'READY' &&
                      cv['latestArtifactId'] != null,
                )
                .toList();
            return DropdownButtonFormField<int>(
              initialValue: artifactId,
              decoration: const InputDecoration(labelText: 'CV đã có'),
              items: items
                  .map(
                    (cv) => DropdownMenuItem<int>(
                      value: (cv['latestArtifactId'] as num).toInt(),
                      child: Text('${cv['title']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                artifactId = value;
                cvTitle = null;
              }),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : pickCv,
          icon: const Icon(Icons.upload_file),
          label: Text(cvTitle ?? 'Tải CV PDF mới'),
        ),
        TextField(
          controller: cover,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Thư giới thiệu (không bắt buộc)',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : apply,
          child: const Text('Gửi đơn ứng tuyển'),
        ),
      ],
    ),
  );
}

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key, required this.active});
  final bool active;
  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  int page = 0;
  late Future<dynamic> result = load();
  Future<dynamic> load() => api.get(
    '/students/me/applications',
    query: {'page': '$page', 'size': '10'},
  );
  @override
  void didUpdateWidget(ApplicationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) setState(() => result = load());
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: DataList(
          result: result,
          builder: (items) => ListView(
            children: items
                .map(
                  (item) => Card(
                    child: ListTile(
                      title: Text('${item['jobTitle']}'),
                      subtitle: Text(
                        '${item['companyName']} · ${item['status']}',
                      ),
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('${item['jobTitle']}'),
                          content: Text(
                            'Trạng thái: ${item['status']}\nCV: ${item['cvTitle'] ?? ''}\n${item['statusNote'] ?? ''}',
                          ),
                          actions: [
                            if (item['status'] == 'APPLIED' ||
                                item['status'] == 'PENDING')
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  try {
                                    await api.patch(
                                      '/students/me/applications/${item['id']}/cancel',
                                      {},
                                    );
                                    if (mounted) {
                                      setState(() => result = load());
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      showError(context, error);
                                    }
                                  }
                                },
                                child: const Text('Hủy đơn'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Đóng'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      PageControls(
        result: result,
        page: page,
        previous: page > 0
            ? () => setState(() {
                page--;
                result = load();
              })
            : null,
        next: () => setState(() {
          page++;
          result = load();
        }),
      ),
    ],
  );
}

class PageControls extends StatelessWidget {
  const PageControls({
    super.key,
    required this.result,
    required this.page,
    required this.previous,
    required this.next,
  });
  final Future<dynamic> result;
  final int page;
  final VoidCallback? previous;
  final VoidCallback next;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: result,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final data = snapshot.data as Map<String, dynamic>;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: previous, icon: const Icon(Icons.chevron_left)),
          Text('Trang ${page + 1} / ${data['totalPages']}'),
          IconButton(
            onPressed: data['last'] == false ? next : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );
    },
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.active, required this.onLogout});
  final bool active;
  final VoidCallback onLogout;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<dynamic> profile = api.get('/student-profiles/me');
  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      setState(() => profile = api.get('/student-profiles/me'));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: profile,
    builder: (context, snapshot) {
      final data = snapshot.data is Map
          ? Map<String, dynamic>.from(snapshot.data as Map)
          : <String, dynamic>{};
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${api.user?['fullName'] ?? ''}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('${api.user?['email'] ?? ''}'),
          const SizedBox(height: 16),
          if (snapshot.hasError)
            Text('Chưa có hồ sơ sinh viên: ${snapshot.error}'),
          if (snapshot.hasData) ...[
            Text('Trường: ${data['university'] ?? 'Chưa cập nhật'}'),
            Text('Ngành: ${data['major'] ?? 'Chưa cập nhật'}'),
            Text('Thành phố: ${data['city'] ?? 'Chưa cập nhật'}'),
          ],
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileEditPage(profile: data),
                ),
              );
              setState(() => profile = api.get('/student-profiles/me'));
            },
            child: const Text('Cập nhật hồ sơ'),
          ),
          TextButton(
            onPressed: () async {
              await api.logout();
              widget.onLogout();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      );
    },
  );
}

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.profile});
  final Map<String, dynamic> profile;
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final university = TextEditingController(
    text: '${widget.profile['university'] ?? ''}',
  );
  late final major = TextEditingController(
    text: '${widget.profile['major'] ?? ''}',
  );
  late final city = TextEditingController(
    text: '${widget.profile['city'] ?? ''}',
  );
  late final phone = TextEditingController(
    text: '${widget.profile['phone'] ?? ''}',
  );
  @override
  void dispose() {
    university.dispose();
    major.dispose();
    city.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final body = {
      'university': university.text.trim(),
      'major': major.text.trim(),
      'city': city.text.trim(),
      'phone': phone.text.trim(),
    };
    try {
      if (widget.profile.isEmpty) {
        await api.post('/student-profiles', body);
      } else {
        await api.patch('/student-profiles/me', body);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ sinh viên')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: university,
          decoration: const InputDecoration(labelText: 'Trường học'),
        ),
        TextField(
          controller: major,
          decoration: const InputDecoration(labelText: 'Ngành học'),
        ),
        TextField(
          controller: city,
          decoration: const InputDecoration(labelText: 'Thành phố'),
        ),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Số điện thoại'),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: save, child: const Text('Lưu hồ sơ')),
      ],
    ),
  );
}
