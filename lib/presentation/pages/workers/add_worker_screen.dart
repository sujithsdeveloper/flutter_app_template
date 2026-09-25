import 'package:flutter/material.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:mess_app/data/repositories/plot_repository.dart';
import 'package:mess_app/data/repositories/worker_plot_repository.dart';
import 'package:mess_app/presentation/blocs/workers/workers_cubit.dart';
import 'package:mess_app/presentation/widgets/custom_textfield.dart';
import 'package:mess_app/presentation/widgets/plot_assignment_picker.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';

/// Form for adding or editing a field volunteer with plot assignment.
class AddWorkerScreen extends StatefulWidget {
  const AddWorkerScreen({
    super.key,
    required this.t,
    required this.cubit,
    this.worker,
  });

  final AppText t;
  final WorkersCubit cubit;

  /// When set, the form opens in edit mode for this volunteer.
  final WorkerModel? worker;

  bool get isEditing => worker != null;

  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _plotRepo = getIt<PlotRepository>();
  final _workerPlotRepo = getIt<WorkerPlotRepository>();

  List<PlotModel> _plots = [];
  Set<String> _selectedPlotIds = {};
  bool _isActive = true;
  bool _loadingPlots = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final worker = widget.worker;
    if (worker != null) {
      _nameCtrl.text = worker.name;
      _phoneCtrl.text = worker.phone ?? '';
      _isActive = worker.isActive;
    }
    _loadPlots();
  }

  Future<void> _loadPlots() async {
    final plots = await _plotRepo.getAssignedPlots();
    Set<String> selected = {};
    final worker = widget.worker;
    if (worker != null) {
      final ids = await _workerPlotRepo.getPlotIdsForWorker(worker.id);
      selected = ids.toSet();
    }
    if (!mounted) return;
    setState(() {
      _plots = plots;
      _selectedPlotIds = selected;
      _loadingPlots = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final bool success;
    if (widget.isEditing) {
      success = await widget.cubit.updateWorker(
        workerId: widget.worker!.id,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        isActive: _isActive,
        plotIds: _selectedPlotIds.toList(),
      );
    } else {
      success = await widget.cubit.addWorker(
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        plotIds: _selectedPlotIds.toList(),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      SnackbarHelper.showSucces(
        context: context,
        message: widget.isEditing
            ? widget.t.workerUpdated
            : widget.t.workerSaved,
      );
      Navigator.pop(context, true);
    } else {
      SnackbarHelper.showError(
        context: context,
        message: widget.isEditing
            ? widget.t.workerUpdateFailed
            : widget.t.workerSaveFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Scaffold(
      backgroundColor: ColorConstants.lightBackground,
      appBar: AppBar(
        backgroundColor: ColorConstants.lightBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: ColorConstants.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditing ? t.editWorker : t.addWorker,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ColorConstants.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 36,
                  color: ColorConstants.forestGreen,
                ),
              ),
            ),
            const SizedBox(height: 28),
            CustomTextField(
              controller: _nameCtrl,
              labelText: t.workerName,
              hintText: t.workerNameHint,
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return t.workerName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneCtrl,
              labelText: t.workerPhone,
              hintText: t.workerPhoneHint,
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              keyboardType: TextInputType.phone,
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ColorConstants.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColorConstants.borderGrey),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.activeStatus,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ColorConstants.lightTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _isActive ? t.active : t.inactive,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isActive
                          ? ColorConstants.successColor
                          : ColorConstants.lightTextSecondary,
                    ),
                  ),
                  value: _isActive,
                  activeThumbColor: ColorConstants.forestGreen,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
            ],
            const SizedBox(height: 28),
            if (_loadingPlots)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ColorConstants.forestGreen,
                    ),
                  ),
                ),
              )
            else
              PlotAssignmentPicker(
                t: t,
                plots: _plots,
                selectedPlotIds: _selectedPlotIds,
                onChanged: (ids) => setState(() => _selectedPlotIds = ids),
              ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: widget.isEditing ? t.saveChanges : t.saveWorker,
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
