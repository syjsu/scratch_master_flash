/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// .as
// , June 2010
//
//  primitives.

package primitives {
	import blocks.Block;
	import flash.utils.Dictionary;
	import interpreter.*;
	import scratch.*;
	import flash.utils.ByteArray;
	import arduino.ArduinoLibrary;
	import arduino.ArduinoUart;
	import flash.filesystem.FileMode;

public class CfunPrims {

	private var app:Scratch;
	private var interp:Interpreter;
	
	//arduino
	public var ArduinoFlag:Boolean      = false;        //是否需要生成Arduino程序
	public var ArduinoLoopFlag:Boolean  = false;    //是否进入Loop
	public var ArduinoReadFlag:Boolean  = false;    //当前同一条目下是否为读操作
	public var ArduinoReadStr:Array     = new Array;   //先存储读的Arduino语句
	public var ArduinoValueFlag:Boolean = false;   //是否有变量保持字符类型
	public var ArduinoValueStr:String   = new String;//变量字符型
	public var ArduinoMathFlag:Boolean  = false;    //是否有运算保持字符类
	public var ArduinoMathStr:Array     = new Array;   //运算字符型
	public var ArduinoMathNum:Number    = 0;          //运算嵌入层数
	
	//Arduino 中可驱动的模块
	public var ArduinoUs:Boolean  = false;//超声波
	public var ArduinoSeg:Boolean = false;//数码管
	public var ArduinoRGB:Boolean = false;//三色灯
	public var ArduinoBuz:Boolean = false;//无源蜂鸣器
	public var ArduinoCap:Boolean = false;//电容值
	public var ArduinoDCM:Boolean = false;//方向电机
	public var ArduinoSer:Boolean = false;//舵机
	public var ArduinoIR:Boolean  = false;//红外遥控
	public var ArduinoTem:Boolean = false;//温度
	public var ArduinoAvo:Boolean = false;//避障
	public var ArduinoTra:Boolean = false;//循迹
	public var ArduinoLCD1602:Boolean = false;//LCD1602
	

	public function CfunPrims(app:Scratch, interpreter:Interpreter) {
		this.app = app;
		this.interp = interpreter;
	}

	public function addPrimsTo(primTable:Dictionary):void {
		
		//  Arduino Block
		primTable["whenArduino"]           = primArduino;   //Arduino程序头_wh
		
		primTable["readdigital:"]          = primReadDio;   //读数字口输入
		primTable["readanalog:"]           = primReadAio;   //读数字口输入
		primTable["setdigital:"]           = primSetDigital;//写数字口输出_wh
		primTable["setpwm:"]               = primSetPWM;    //写PWM口输出_wh
		
		primTable["readcap:"]              = primReadByte;//读数字口输入_wh
		primTable["readcapSend:"]          = primReadCap;//读数字口输入命令发送_wh
		primTable["readfraredR:"]          = primReadByte;//读红外遥控输入_wh
		primTable["readfraredRSend:"]      = primReadFraredR;//读红外遥控输入_wh
		primTable["readAfloat:"]           = primReadFloat;//读模拟口输入float值_wh
		primTable["readAfloatSend:"]       = primReadAFloat;//读模拟口输入float值命令发送_wh
		primTable["readPfloat:"]           = primReadFloat;//读超声波输入float值_wh
		primTable["readPfloatSend:"]       = primReadPFloat;//读超声波输入float值命令发送_wh
		
		primTable["setsg:"]                = primSetSG;//写舵机输出角度_wh
		primTable["setdm:"]                = primSetDM;//写电机正负PWM输出_wh
		primTable["setnum:"]               = primSetNUM;//写数码管输出值_wh
		primTable["setmusic:"]             = primSetMUS;//写无源蜂鸣器音乐输出值_wh
		primTable["setLCD1602string:"]     = primSetLCD1602String;
		
		//Arduino Robot   板上的固定的传感器
		primTable["readcksound"]			= function(b:*):* { return app.arduinoLib.arduinoSoundValue};
		primTable["readckslide"]	        = function(b:*):* { return app.arduinoLib.arduinoSlideValue};
		primTable["readcklight"]		    = function(b:*):* { return app.arduinoLib.arduinoLightValue};
		primTable["readckUltrasonicSensor"]	= function(b:*):* { return app.arduinoLib.arduinoUltrasonicValue};	
		
		primTable["readtrack:"]             = primReadShort;//读循迹输入_wh
		primTable["readtrackSend:"]         = primReadTrack;//读循迹输入_wh
		primTable["readavoid:"]             = primReadShort;//读红外避障输入_wh
		primTable["readavoidSend:"]         = primReadAvoid;//读红外避障输入_wh
		
		primTable["readpower:"]             = primReadFloat;//读电量输入_wh
		primTable["readpowerSend:"]         = primReadPower;//读电量输入_wh
		primTable["setgray:"]               = primSetgray;//写机器人灰度阀值_wh
		primTable["setforward:"]            = primSetforward;//写机器人前进速度_wh
		primTable["setback:"]               = primSetback;//写机器人后退速度_wh
		primTable["setleft:"]               = primSetleft;//写机器人左转弯速度_wh
		primTable["setright:"]              = primSetright;//写机器人右转弯速度_wh	
	}
	
	
	private function primArduino(b:Block):void
	{	
		app.arduinoLib.ArduinoLoopFlag    = false;
		app.arduinoLib.ArduinoBracketFlag = 0;
		app.arduinoLib.ArduinoMathFlag    = false;
		app.arduinoLib.ArduinoReadFlag    = false;
		app.arduinoLib.ArduinoValueFlag   = false;
		app.arduinoLib.ArduinoIEFlag      = 0;
		app.arduinoLib.ArduinoIEElseFlag  = 0;
		app.arduinoLib.ArduinoIEFlagIE    = false;
		app.arduinoLib.ArduinoIEFlagAll   = 0;
		app.arduinoLib.ArduinoIEElseNum   = 0;
		app.arduinoLib.ArduinoWarnFlag    = false;
		app.arduinoLib.ArduinoIEFlag2     = 0;
		//app.ArduinoIEBracketFlag = 0;
		
		app.arduinoLib.ArduinoUs  = false;//超声波_wh
		app.arduinoLib.ArduinoSeg = false;//数码管_wh
		app.arduinoLib.ArduinoRGB = false;//三色灯_wh
		app.arduinoLib.ArduinoBuz = false;//无源蜂鸣器_wh
		app.arduinoLib.ArduinoCap = false;//电容值_wh
		app.arduinoLib.ArduinoDCM = false;//方向电机_wh
		app.arduinoLib.ArduinoSer = false;//舵机_wh
		app.arduinoLib.ArduinoIR  = false;//红外遥控_wh
		app.arduinoLib.ArduinoTem = false;//温度_wh
		app.arduinoLib.ArduinoAvo = false;//避障_wh
		app.arduinoLib.ArduinoTra = false;//循迹_wh
		
		app.arduinoLib.ArduinoFlag = true;
		app.arduinoLib.ArduinoPin = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
		var j:Number = 0;
		for(var i:Number = 0; i <= 0xfff; i++)
		{
			switch (i)
			{
				case app.arduinoUart.ID_ReadAFloat:for(j = 0; j <= 13; j++)  app.arduinoLib.ArduinoBlock[app.arduinoUart.ID_ReadAFloat][j] = 0;break;
				case app.arduinoUart.ID_ReadPFloat:for(j = 0; j <= 13; j++)  app.arduinoLib.ArduinoBlock[app.arduinoUart.ID_ReadPFloat][j] = 0;break;
				case app.arduinoUart.ID_SetSG:for(j = 0; j <= 13; j++)  app.arduinoLib.ArduinoBlock[app.arduinoUart.ID_SetSG][j] = 0;break;
				case app.arduinoUart.ID_SetDM:for(j = 0; j <= 13; j++)  app.arduinoLib.ArduinoBlock[app.arduinoUart.ID_SetDM][j] = 0;break;
				case app.arduinoUart.ID_SetNUM:for(j = 0; j <= 13; j++)  app.arduinoLib.ArduinoBlock[app.arduinoUart.ID_SetNUM][j] = 0;break;
				case app.arduinoUart.ID_SetMUS:for(j = 0; j <= 13; j++)  app.arduinoLib.ArduinoBlock[app.arduinoUart.ID_SetMUS][j] = 0;break;
				default:app.arduinoLib.ArduinoBlock[i] = 0;break;
			}
		}
		
		app.arduinoLib.ArduinoPinFs.open(app.arduinoLib.ArduinoPinFile,FileMode.WRITE);
		app.arduinoLib.ArduinoPinFs.position = 0;
		
		app.arduinoLib.ArduinoDoFs.open(app.arduinoLib.ArduinoDoFile,FileMode.WRITE);
		app.arduinoLib.ArduinoDoFs.position = 0;
		
		app.arduinoLib.ArduinoHeadFs.open(app.arduinoLib.ArduinoHeadFile,FileMode.WRITE);
		app.arduinoLib.ArduinoHeadFs.position = 0;
		
		app.arduinoLib.ArduinoLoopFs.open(app.arduinoLib.ArduinoLoopFile,FileMode.WRITE);
		app.arduinoLib.ArduinoLoopFs.position = 0;
		
		app.arduinoLib.ArduinoFs.open(app.arduinoLib.ArduinoFile,FileMode.WRITE);
		app.arduinoLib.ArduinoFs.position = 0;
	}
	
	//读数字口输入
	private function primReadDio(b:Block):Boolean
	{			
		var pin:Number = interp.numarg(b, 0);//引脚号，模块参数第一个，参数类型为数字
		switch(pin)
		{
			case 0x02:
				return app.arduinoLib.arduinoDIOPin2;
			case 0x03:
				return app.arduinoLib.arduinoDIOPin3;
			case 0x04:
				return app.arduinoLib.arduinoDIOPin4;
			case 0x05:
				return app.arduinoLib.arduinoDIOPin5;
			case 0x06:
				return app.arduinoLib.arduinoDIOPin6;
			case 0x07:
				return app.arduinoLib.arduinoDIOPin7;
			case 0x08:
				return app.arduinoLib.arduinoDIOPin8;
			case 0x09:
				return app.arduinoLib.arduinoDIOPin9;
			case 0x0a:
				return app.arduinoLib.arduinoDIOPin10;
			case 0x0b:
				return app.arduinoLib.arduinoDIOPin11;
			case 0x0c:
				return app.arduinoLib.arduinoDIOPin12;
			case 0x0d:
				return app.arduinoLib.arduinoDIOPin13;
			default:
				break;			
		}
		return false;
	}
	
	//读模拟口输入
	private function primReadAio(b:Block):Boolean
	{			
		var pin:Number = interp.numarg(b, 0);//引脚号，模块参数第一个，参数类型为数字
		switch(pin)
		{
			case 0x00:
				return app.arduinoLib.arduinoAIOPin0;
			case 0x01:
				return app.arduinoLib.arduinoAIOPin1;
			case 0x02:
				return app.arduinoLib.arduinoAIOPin2;
			case 0x03:
				return app.arduinoLib.arduinoAIOPin3;
			case 0x04:
				return app.arduinoLib.arduinoAIOPin4;
			case 0x05:
				return app.arduinoLib.arduinoAIOPin5;
			default:
				break;			
		}
		return false;
	}
	
	private function primSetDigital(b:Block):Boolean
	{
		app.xuhy_test_log("primSetDigital");
		var pin:Number = interp.numarg(b, 0);  //找到需要设置的IO口
		
		var DIOStatus:Number = 0x00;           //找到该IO口需要设置的数据
		if(interp.arg(b,1) == 'low')
			DIOStatus = 0;
		else
			DIOStatus = 1;
		return  false;
		// 下发通讯协议			
	}
	
	
	private function primSetPWM(b:Block):Boolean
	{
		app.xuhy_test_log("primSetPWM");
		var pin:Number = interp.numarg(b,0);
		return false;
	}
	
	private function primReadByte(b:Block):int
	{
		app.xuhy_test_log("primReadByte");
		return 0x00;
	}
	
	private function primReadCap(b:Block):void
	{
		
	}
	
	private function primReadFraredR(b:Block):void
	{
	
	}
	
	private function primReadFloat(b:Block):void
	{
		
	}
	
	private function primReadAFloat(b:Block):void
	{
		
	}
	
	private function primReadPFloat(b:Block):void
	{
		
	}
	
	private function primSetSG(b:Block):void
	{
		
	}
	
	private function primSetDM(b:Block):void
	{
		
	}
	
	private function primSetNUM(b:Block):void
	{
		
	}
	private function primSetMUS(b:Block):void
	{
		
	}
	private function primSetLCD1602String(b:Block):void
	{
		
	}
	private function primReadShort(b:Block):void
	{
		
	}
	private function primReadTrack(b:Block):void
	{
		
	}	
	private function primReadAvoid(b:Block):void
	{
		
	}
	private function primReadPower(b:Block):void
	{
		
	}
	private function primSetgray(b:Block):void
	{
		
	}
	private function primSetforward(b:Block):void
	{
		
	}
	private function primSetback(b:Block):void
	{
		
	}
	private function primSetleft(b:Block):void
	{
		
	}
	private function primSetright(b:Block):void
	{
		
	}
			
	
	
}}
