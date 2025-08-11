import 'package:flutter/material.dart';

class Debt extends StatefulWidget {
  const Debt({
    Key? key,
    }): super(key: key);
  @override
  DebtState createState() => DebtState();
}

class DebtState extends State<Debt> {
  double debtTotal = 0.0;

  double zhongxin = 0.0;
  double zhongxinTotal = 80000;

  double ccb = 0.0;
  double ccbTotal = 44000;

  double pufa = 0.0;
  double pufaTotal = 49000;

  double guangfa = 0.0;
  double guangfaTotal = 124500;

  double zhaohang = 0.0;
  double zhaohangTotal = 60000;

  double pingan = 0.0;
  double pinganTotal = 50000;

  double gonghang = 0.0;
  double gonghangTotal = 19000;

  double huaxia = 0.0;
  double huaxiaTotal = 23400;

  double jiaohang = 0.0;
  double jiaohangTotal = 57000;

  final TextEditingController zhongxinController = TextEditingController();
  final TextEditingController ccbController = TextEditingController();
  final TextEditingController pufaController = TextEditingController();
  final TextEditingController guangfaController = TextEditingController();
  final TextEditingController zhaohangController = TextEditingController();
  final TextEditingController pinganController = TextEditingController();
  final TextEditingController gonghangController = TextEditingController();
  final TextEditingController huaxiaController = TextEditingController();
  final TextEditingController jiaohangController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
  }

  void zhongxinChanged(String str){
    if(str != ''){
      setState((){
        zhongxin = double.parse(str);
      });
    }
  }

  void ccbChanged(String str){
    if(str != ''){
      setState((){
        ccb = double.parse(str);
      });
    }
  }

  void pufaChanged(String str){
    if(str != ''){
      setState((){
        pufa = double.parse(str);
      });
    }
  }

  void guangfaChanged(String str){
    if(str != ''){
      setState((){
        guangfa = double.parse(str);
      });
    }
  }

  void zhaohangChanged(String str){
    if(str != ''){
      setState((){
        zhaohang = double.parse(str);
      });
    }
  }

  void pinganChanged(String str){
    if(str != ''){
      setState((){
        pingan = double.parse(str);
      });
    }
  }

  void gonghangChanged(String str){
    if(str != ''){
      setState((){
        gonghang = double.parse(str);
      });
    }
  }

  void huaxiaChanged(String str){
    if(str != ''){
      setState((){
        huaxia = double.parse(str);
      });
    }
  }

  void jiaohangChanged(String str){
    if(str != ''){
      setState((){
        jiaohang = double.parse(str);
      });
    }
  }

  void _cal(){
    setState(() {
      debtTotal = zhongxinTotal - zhongxin + ccbTotal - ccb + pufaTotal - pufa + guangfaTotal - guangfa + zhaohangTotal - zhaohang + pinganTotal - pingan + huaxiaTotal - huaxia + gonghangTotal - gonghang + jiaohangTotal - jiaohang;
    });
  }

  void clear(){
    zhongxinController.text = '';
    ccbController.text = '';
    pufaController.text = '';
    guangfaController.text = '';
    zhaohangController.text = '';
    pinganController.text = '';
    jiaohangController.text = '';
    huaxiaController.text = '';
    gonghangController.text = '';
    setState(() {
      debtTotal = 0;
    });
  }

  @override
  void dispose() {
    super.dispose();
    zhongxinController.dispose();
    ccbController.dispose();
    pufaController.dispose();
    guangfaController.dispose();
    zhaohangController.dispose();
    huaxiaController.dispose();
    gonghangController.dispose();
    pinganController.dispose();
    jiaohangController.dispose();
  }

  Widget item(String title, String subtitle, controller, onChange){
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 5),
      child: Row(
          children: [
            Column(children: [
              Text(title, style: const TextStyle(fontSize: 20),),
              subtitle == ''
              ? Container()
              : Text(subtitle, style: const TextStyle(fontSize: 15)),
            ],),
            Expanded(
              flex: 1,
              child: Container(
            )),
            SizedBox(
              height: 50,
              width: 150,
              child:TextField(
                onChanged: onChange,
                controller: controller,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  hintText: '剩余：',
                  hintStyle: TextStyle(color: Colors.grey)
                ),
              )
            )
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('债务计算器'),
        centerTitle:true,
        actions: [IconButton(icon: const Icon(Icons.calculate), onPressed: _cal)],
      ),
      body: ListView(
        children: [
          const Divider(),
          item('中信', zhongxinTotal.toString(), zhongxinController, zhongxinChanged),
          item('建行', ccbTotal.toString(), ccbController, ccbChanged),
          item('浦发', pufaTotal.toString(), pufaController, pufaChanged),
          item('广发', guangfaTotal.toString(), guangfaController, guangfaChanged),
          item('招行', zhaohangTotal.toString(), zhaohangController , zhaohangChanged),
          item('平安', pinganTotal.toString(), pinganController, pinganChanged),
          item('工行', gonghangTotal.toString(), gonghangController, gonghangChanged),
          item('交行', jiaohangTotal.toString(), jiaohangController, jiaohangChanged),
          item('华夏', huaxiaTotal.toString(), huaxiaController, huaxiaChanged),
          debtTotal == 0
          ? Center(
            child: Text('总额度：${zhongxinTotal+ccbTotal+pufaTotal+guangfaTotal+zhaohangTotal+pinganTotal+gonghangTotal+jiaohangTotal+huaxiaTotal}', style: const TextStyle(fontSize: 30)),
          )
          :Column(
            children: [
              GestureDetector(
                onTap: clear,
                child: Text('总负债：$debtTotal', style: const TextStyle(fontSize: 30),),
              )
              //Text('比上次计算', style: TextStyle(fontSize: 20))
            ],
          )
        ],
      )
    );
  }
}