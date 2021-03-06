#
#	(Funciona correctamente con Mars 4.5)
#
#	En caso de que el juego crashee, es posible que haya que aumentar el valor
#	de la constante "delayTiempo" (milisegundos) definida en el .data
#	Aunque siempre esta la posibilidad de que crashee. Modulo del teclado
#	no funciona correctamente.
#
#	Usar Tools -> Bitmap Display
#	Usar Tools -> Keyboard and Display (MMIO) Simulator
#
#	Conectar ambos dispositivos haciendo click en "Connect to MIPS"
#
#	Configurar Bitmap Display
#		Unit Width in Pixels: 8
#		Unit Height in Pixels: 8
#		Display Width in Pixels: 512
#		Display Height in Pixels: 512
#		Base address for display 0x10010000 (static data)
#	
#	Teclado
#		W
#	A	S	D		Q = terminar partida
#					espacio = crecer cola (trampa)
#
#	Creado por Felipe Vilches Cespedes
.data
	
	display: .word 0:4096		# Dimension 64x64 cuadros en la matriz
					
	obstaculos: .space 800		# Habran 100 obstaculos en cada mapa (cantidad constante)
					# (coordenadas X Y son 4 bytes cada uno)
					# 8 bytes por obstaculo, y como son 100... 8*100 = 800 bytes de memoria para los obstaculos
	# Constantes
	
	delayTiempo:		.word 150	# Tiempo de delay en el loop del juego
	mapaAncho:		.word 64	# Ancho (X) del mapa jugable
	mapaAltura:		.word 54	# Altura (Y) del mapa jugable
		
	# Strings
	mensajeBienvenida:	.asciiz "\n############################\n############################\n############################\nBienvenido, este juego fue creado por Felipe Vilches Cespedes.\nInstrucciones:\nArriba = w\nAbajo = s\nIzquierda = a\nDerecha = d\nReiniciar partida = q\nCrecer cola = Espacio (crece la cola sin necesidad de comer una comida, usado para debuggear)"
	.align 2
	
	# Variables (Se reserva memoria, pero son inicializadas luego)
	
	largoCola:		.space 4	# El largo de la cola de la serpiente. Cuando comienza el juego esta es 0.
	largoColaAux:		.space 4	# Para comprobar si la cola ha crecido de un frame a otro.
	direccion:		.space 4	# Direccion, hacia donde se mueve la serpiente. (1|2|3|4)
	comidaX:		.space 4	# Posicion X de la comida, dentro de la matriz.
	comidaY:		.space 4	# Posicion Y de la comida, dentro de la matriz.	
	cabezaSerpienteX:	.space 4	# Posicion X de la cabeza de la serpiente.
	cabezaSerpienteY:	.space 4	# Posicion Y de la cabeza de la serpiente.	
	juegoEnMovimiento:	.space 4	# Verdadero o falso. El juego esta o no movimiento (cada partida comienza pausada).
	
	
.text
	
	###################################################################
	###################################################################
	####################### JUEGO PRINCIPAL ###########################
	###################################################################
	###################################################################
	
	Intro: 
		# Al iniciar la aplicacion, comienza una pantalla que muestra un mensaje "Snake"
		# escrito pixel por pixel. Luego de esta pantalla, comienza el juego MAIN
	
		la $a0, mensajeBienvenida
		li $v0, 4
		syscall		
		jal animacionIntro		
		
	Main:					# "Main" contiene todo el juego principal (mover la serpiente, chequear colisiones, perder, etc).
			
				
		jal iniciarPartidaDesdeCero	# Reinicia todos los valores de la partida

		MainJuego:			# Comienza el loop del juego principal	
		
			jal obtenerTeclado		# Obtiene la tecla que se ha presionado y realiza cambios en el juego.

			la $t0, juegoEnMovimiento	# Chequea si el juego esta en movimiento.
			lw $t0, 0($t0)			
			bnez $t0, movimientoIniciado	# Si esta en movimiento, saltar a "movimientoIniciado".
			beqz $t0, MainJuego		# Vuelve a MainJuego, sin que se ejecute el resto
								
			movimientoIniciado:
			
				jal despintarRegionesRedibujo		# Despinta regiones de redibujo (las que se deben actualizar)
				jal moverColaSerpiente			# Mueve las posiciones de la cola de la serpiente					
				jal moverCabezaSerpiente		# Mueve las posiciones de la cabeza de la serpiente			
				jal chequearComeComida			# Chequea si ha comido alguna comida					
				jal pintarTodo				# Pintar cabeza, comida y cola de serpiente
				
				la $t0, largoCola			 
				lw $t0, 0($t0)				# t0 = largo Cola
				la $t1, largoColaAux			
				lw $t1, 0($t1)				# t1 = largo Cola auxiliar
				beq $t0, $t1, noActualizarPuntaje	# si son iguales, no actualiza puntaje
				
				jal pintarDigitosPuntaje		# Pintar digitos del puntaje (se actualiza el display de puntaje)
				
				la $t0, largoCola			# t0 = direccion largoCola
				lw $t0, 0($t0)				# t0 = largo cola
				la $t1, largoColaAux			# t1 = direccion largoColaAux
				sw $t0, 0($t1)				# largoColaAux = largoCola
				
				noActualizarPuntaje:
				
				jal chequearColisionConsigoMisma	# Chequea si la serpiente colisiona consigo misma
				bnez $v0,perderPartida			# Perder partida en caso de que haya colision consigo misma
				
				la $a0, cabezaSerpienteX		# (preparando argumentos para chequear colision con obstaculos)
				lw $a0, 0($a0)				# a0 = cabeza.x 
				la $a1, cabezaSerpienteY
				lw $a1, 0($a1)				# a1 = cabeza.y
				jal chequearColisionObstaculos		# Chequea si la serpiente ha colisionado con algun obstaculo
				bnez $v0,perderPartida			# Perder partida en caso de que haya colisionado con algun obstaculo
			
				jal dormir				# Pausar ejecucion por algunos milisegundos
				
		j MainJuego						# Volver al ciclo del juego
		
		perderPartida:						# Perder partida
			li $a0, 3000					# Detener ejecucion del juego por un tiempo mas largo
			jal dormirUsandoOtroValorDeTiempo		# 
			j Main						# Volver a main, iniciar partida desde cero
		
	# Fin del juego principal. Ahora se definen las subrutinas (funciones) que fueron usadas
	# en este "main".
		
	###################################################################
	###################################################################
	################## DEFINICION DE SUBRUTINAS #######################
	###################################################################
	###################################################################
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Pinta una barra de color diferente abajo de la pantalla, para indicar que eso no es	
	# parte del mapa jugable
	pintarBarraInferior:
		la $t0, mapaAncho
		lw $t0, 0($t0)
		la $t1, mapaAltura
		lw $t1, 0($t1)
		mult $t1, $t0
		mflo $t0		# t0 = ancho por altura del mapa jugable
		sll $t3, $t0, 2	
		la $t1, display
		add $t1, $t1, $t3
		li $t2, 0x222222	# t2 = color
		
		forPintarBarraInferior:
			beq $t0, 4096, finForPintarBarraInferior	# i == 4096
			sw $t2, 0($t1)		# color guardado en direccion a pintar
			addi $t1, $t1, 4	# direccion a pintar
			addi $t0, $t0, 1	# i++
			j forPintarBarraInferior
		finForPintarBarraInferior:
	
	jr $ra
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Animacion para la intro, pone el mensaje "Snake" dibujado en el display
	animacionIntro:
		move $s0, $ra
		li $a0, 0xff0000
		jal pintarFondo	
		
		
		li $a0, 5
		li $a1, 8
		jal pintarCuadro
		li $a0, 6
		li $a1, 8
		jal pintarCuadro
		li $a0, 7
		li $a1, 8
		jal pintarCuadro
		li $a0, 8
		li $a1, 8
		jal pintarCuadro
		li $a0, 9
		li $a1, 8
		jal pintarCuadro
		li $a0, 12
		li $a1, 8
		jal pintarCuadro
		li $a0, 19
		li $a1, 8
		jal pintarCuadro
		li $a0, 25
		li $a1, 8
		jal pintarCuadro
		li $a0, 31
		li $a1, 8
		jal pintarCuadro
		li $a0, 35
		li $a1, 8
		jal pintarCuadro
		li $a0, 39
		li $a1, 8
		jal pintarCuadro
		li $a0, 40
		li $a1, 8
		jal pintarCuadro
		li $a0, 41
		li $a1, 8
		jal pintarCuadro
		li $a0, 42
		li $a1, 8
		jal pintarCuadro
		li $a0, 43
		li $a1, 8
		jal pintarCuadro
		li $a0, 44
		li $a1, 8
		jal pintarCuadro
		li $a0, 4
		li $a1, 9
		jal pintarCuadro
		li $a0, 12
		li $a1, 9
		jal pintarCuadro
		li $a0, 13
		li $a1, 9
		jal pintarCuadro
		li $a0, 19
		li $a1, 9
		jal pintarCuadro
		li $a0, 24
		li $a1, 9
		jal pintarCuadro
		li $a0, 26
		li $a1, 9
		jal pintarCuadro
		li $a0, 31
		li $a1, 9
		jal pintarCuadro
		li $a0, 34
		li $a1, 9
		jal pintarCuadro
		li $a0, 39
		li $a1, 9
		jal pintarCuadro
		li $a0, 4
		li $a1, 10
		jal pintarCuadro
		li $a0, 12
		li $a1, 10
		jal pintarCuadro
		li $a0, 14
		li $a1, 10
		jal pintarCuadro
		li $a0, 19
		li $a1, 10
		jal pintarCuadro
		li $a0, 23
		li $a1, 10
		jal pintarCuadro
		li $a0, 27
		li $a1, 10
		jal pintarCuadro
		li $a0, 31
		li $a1, 10
		jal pintarCuadro
		li $a0, 33
		li $a1, 10
		jal pintarCuadro
		li $a0, 39
		li $a1, 10
		jal pintarCuadro
		li $a0, 4
		li $a1, 11
		jal pintarCuadro
		li $a0, 12
		li $a1, 11
		jal pintarCuadro
		li $a0, 15
		li $a1, 11
		jal pintarCuadro
		li $a0, 19
		li $a1, 11
		jal pintarCuadro
		li $a0, 22
		li $a1, 11
		jal pintarCuadro
		li $a0, 28
		li $a1, 11
		jal pintarCuadro
		li $a0, 31
		li $a1, 11
		jal pintarCuadro
		li $a0, 32
		li $a1, 11
		jal pintarCuadro
		li $a0, 39
		li $a1, 11
		jal pintarCuadro
		li $a0, 40
		li $a1, 11
		jal pintarCuadro
		li $a0, 41
		li $a1, 11
		jal pintarCuadro
		li $a0, 42
		li $a1, 11
		jal pintarCuadro
		li $a0, 43
		li $a1, 11
		jal pintarCuadro
		li $a0, 44
		li $a1, 11
		jal pintarCuadro
		li $a0, 5
		li $a1, 12
		jal pintarCuadro
		li $a0, 6
		li $a1, 12
		jal pintarCuadro
		li $a0, 7
		li $a1, 12
		jal pintarCuadro
		li $a0, 8
		li $a1, 12
		jal pintarCuadro
		li $a0, 12
		li $a1, 12
		jal pintarCuadro
		li $a0, 16
		li $a1, 12
		jal pintarCuadro
		li $a0, 19
		li $a1, 12
		jal pintarCuadro
		li $a0, 22
		li $a1, 12
		jal pintarCuadro
		li $a0, 28
		li $a1, 12
		jal pintarCuadro
		li $a0, 31
		li $a1, 12
		jal pintarCuadro
		li $a0, 33
		li $a1, 12
		jal pintarCuadro
		li $a0, 39
		li $a1, 12
		jal pintarCuadro
		li $a0, 9
		li $a1, 13
		jal pintarCuadro
		li $a0, 12
		li $a1, 13
		jal pintarCuadro
		li $a0, 17
		li $a1, 13
		jal pintarCuadro
		li $a0, 19
		li $a1, 13
		jal pintarCuadro
		li $a0, 22
		li $a1, 13
		jal pintarCuadro
		li $a0, 23
		li $a1, 13
		jal pintarCuadro
		li $a0, 24
		li $a1, 13
		jal pintarCuadro
		li $a0, 25
		li $a1, 13
		jal pintarCuadro
		li $a0, 26
		li $a1, 13
		jal pintarCuadro
		li $a0, 27
		li $a1, 13
		jal pintarCuadro
		li $a0, 28
		li $a1, 13
		jal pintarCuadro
		li $a0, 31
		li $a1, 13
		jal pintarCuadro
		li $a0, 34
		li $a1, 13
		jal pintarCuadro
		li $a0, 39
		li $a1, 13
		jal pintarCuadro
		li $a0, 9
		li $a1, 14
		jal pintarCuadro
		li $a0, 12
		li $a1, 14
		jal pintarCuadro
		li $a0, 18
		li $a1, 14
		jal pintarCuadro
		li $a0, 19
		li $a1, 14
		jal pintarCuadro
		li $a0, 22
		li $a1, 14
		jal pintarCuadro
		li $a0, 28
		li $a1, 14
		jal pintarCuadro
		li $a0, 31
		li $a1, 14
		jal pintarCuadro
		li $a0, 35
		li $a1, 14
		jal pintarCuadro
		li $a0, 39
		li $a1, 14
		jal pintarCuadro
		li $a0, 4
		li $a1, 15
		jal pintarCuadro
		li $a0, 5
		li $a1, 15
		jal pintarCuadro
		li $a0, 6
		li $a1, 15
		jal pintarCuadro
		li $a0, 7
		li $a1, 15
		jal pintarCuadro
		li $a0, 8
		li $a1, 15
		jal pintarCuadro
		li $a0, 12
		li $a1, 15
		jal pintarCuadro
		li $a0, 19
		li $a1, 15
		jal pintarCuadro
		li $a0, 22
		li $a1, 15
		jal pintarCuadro
		li $a0, 28
		li $a1, 15
		jal pintarCuadro
		li $a0, 31
		li $a1, 15
		jal pintarCuadro
		li $a0, 36
		li $a1, 15
		jal pintarCuadro
		li $a0, 39
		li $a1, 15
		jal pintarCuadro
		li $a0, 40
		li $a1, 15
		jal pintarCuadro
		li $a0, 41
		li $a1, 15
		jal pintarCuadro
		li $a0, 42
		li $a1, 15
		jal pintarCuadro
		li $a0, 43
		li $a1, 15
		jal pintarCuadro
		li $a0, 44
		li $a1, 15
		jal pintarCuadro
		
		li $a0, 3000
		jal dormirUsandoOtroValorDeTiempo
		move $ra, $s0
	jr $ra
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Obtiene el valor que hay en el teclado y realiza los cambios correspondientes en el programa.
	obtenerTeclado:
		move $s7, $ra
		li $t0, 0xffff0004
		lw $t1, 0($t0)
		
		la $t0, direccion
		lw $t2, 0($t0)		# t2 = direccion actual
		
		# Cheat para agregar un elemento a la cola
		beq $t1, 0x20, espacio		# barra espaciadora
		
		# Con minusculas
		beq $t1, 0x61, izq		# izquierda
		beq $t1, 0x77, up		# arriba
		beq $t1, 0x73, down		# abajo
		beq $t1, 0x64, der		# derecha
		beq $t1, 0x71, terminarPartida  # terminar partida
		
		# Con mayusaculas
		beq $t1, 0x41, izq		# izquierda
		beq $t1, 0x57, up		# arriba
		beq $t1, 0x53, down		# abajo
		beq $t1, 0x44, der		# derecha
		beq $t1, 0x51, terminarPartida  # terminar partida
		
		j obtenerTeclado_FinFuncion
		
		espacio:		
			la $t3, juegoEnMovimiento
			lw $t3, 0($t3)
			beqz $t3, obtenerTeclado_FinFuncion	# Si el juego no se ha empezado a mover, no ejecutar lo siguiente
			jal crecerCola			
			sw $zero, 0xffff0004			# Ahora el teclado tiene valor NULL
			j obtenerTeclado_FinFuncion
			
		terminarPartida:
			j perderPartida
		izq:
			# direccion = 1	
			beq $t2, 3, obtenerTeclado_FinFuncion
			li $t1, 1
			sw $t1, 0($t0)	
			j setearJuegoEnMovimiento
		up:
			# direccion = 2
			beq $t2, 4, obtenerTeclado_FinFuncion
			li $t1, 2
			sw $t1, 0($t0)
			j setearJuegoEnMovimiento
		der:
			# direccion = 3
			beq $t2, 1, obtenerTeclado_FinFuncion
			li $t1, 3
			sw $t1, 0($t0)
			j setearJuegoEnMovimiento
		down:
			# direccion = 4
			beq $t2, 2, obtenerTeclado_FinFuncion
			li $t1, 4
			sw $t1, 0($t0)
			j setearJuegoEnMovimiento
		
		setearJuegoEnMovimiento:
			# juegoEnMovimiento = 1
			la $t0, juegoEnMovimiento
			li $t1, 1
			sw $t1, 0($t0)
		
		obtenerTeclado_FinFuncion:		
		move $ra, $s7
		jr $ra
		
	# Argumentos: $a0, $a1.
	# Retorno: $v0, 
	# Descripcion: numero al azar entre los argumentos, incluyendolos.
	numeroAzar:			

		li $v0, 42		# syscall 42
		syscall			# retorna a a0
		move $v0, $a0		# t2 = primer random number
		
		jr $ra
	
	# Argumentos: -
	# Retorno: - 
	# Descripcion: Detiene la ejecucion esperando un numero fijo de milisegundos.
	dormir:
		li $v0, 32
		la $a0, delayTiempo
		lw $a0, 0($t0)
		syscall
		jr $ra	
	
	# Argumentos: $a0
	# Retorno: - 
	# Descripcion: Detiene la ejecucion esperando $a0 milisegundos. Usada en situaciones especiales en donde
	# se requiere un tiempo distinto al usual.
	dormirUsandoOtroValorDeTiempo:
		li $v0, 32
		syscall
		jr $ra	
		
	# Argumentos: -
	# Retorno: -
	# Descripcion: Borra la cola, reinicia el puntaje a 0 (largo de cola), la cabeza de la serpiente vuelva a su posicion inicial, el juego no esta en movimiento (serpiente aun no empieza a moverse),
	# aparece una nueva comida en algun lugar nuevo.
	iniciarPartidaDesdeCero:
	
		# Guardar la direccion de retorno
		move $s0, $ra
		
		# Obtener tiempo de la maquina y set seed
		li $v0, 30		# syscall 30
		syscall			# obtener tiempo
		move $a1, $a0		# a1 = tiempo maquina
		li $v0, 40		# syscall 40 - set seed
		syscall
	
		jal setCabezaPosicionInicial
		jal vaciarColaSerpienteMemoria		
		jal generarObstaculos
		jal aparecerComidaEnLugarNuevo
		
		# tecla del teclado = 0x00000000
		sw $zero, 0xffff0004
		
		# direccion = 0
		la $t0, direccion
		sw $zero, 0($t0)		
		
		# largoCola = 0
		la $t0, largoCola
		sw $zero, 0($t0)
		
		# largoColaAux = 0
		la $t0, largoColaAux
		sw $zero, 0($t0)
		
		# juegoEnMovimiento = 0
		la $t0, juegoEnMovimiento
		sw $zero, 0($t0)		
		
		# Pintar fondo
		li $a0, 0x000000
		jal pintarFondo
		
		# Pintar obstaculos
		li $a2, 0xa034ab
		jal pintarObstaculos
		
		# Pintar todo
		jal pintarTodo	
		
		# Pintar barra inferior
		jal pintarBarraInferior		
		
		# Pintar puntaje		
		jal pintarDigitosPuntaje		
		
		# Obtener nuevamente la direccion de retorno
		move $ra, $s0
		jr $ra
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Hace que la cabeza de la serpiente aparezca en la posicion inicial, la cual es 
	# encontrada como el punto medio del mapa
	setCabezaPosicionInicial:
	
		# $t0 = ancho mapa
		la $t0, mapaAncho
		lw $t0, 0($t0)
		
		# cabezaSerpienteX = mapaAncho / 2
		srl $t0, $t0, 1
		la $t1, cabezaSerpienteX
		sw $t0, 0($t1)
		
		# $t0 = altura mapa
		la $t0, mapaAltura
		lw $t0, 0($t0)
		
		# cabezaSerpienteX = mapaAltura / 2
		srl $t0, $t0, 1
		la $t1, cabezaSerpienteY
		sw $t0, 0($t1)	
		
		jr $ra
	
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Borra la cola de la serpiente en memoria, volviendo todos los valores a 0.
	vaciarColaSerpienteMemoria:
		la $t0, largoCola
		lw $t0, 0($t0)		# t0 = largoCola
		li $t1, 0		# t1 = 0 ... i=0 
		li $t2, 0x10040000	# direccion heap
		
		forVaciarCola:
			beq $t1, $t0, finVaciarCola			
				sw $zero, 0($t2)
				sw $zero, 4($t2)				
				addi $t2, $t2, 8
		
			addi $t1, $t1, 1	# i++
			j forVaciarCola
		finVaciarCola:
		jr $ra
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: La posicion de la comida cambia a otro lugar
	aparecerComidaEnLugarNuevo:	
		move $s2, $ra
		la $s6, mapaAncho
		lw $s6, 0($s6)		
		addi $s6, $s6, -1
		
		la $s7, mapaAltura
		lw $s7, 0($s7)		
		addi $s7, $s7, -1	
		
		# s6 = ancho - 1
		# s7 = altura - 1		
		
		aparecerComidaEnLugarNuevoGenerarRandom:
		li $a0, 0
		move $a1, $s6		# preparar argumento para la funcion "azar", a1 = ancho-1
		jal numeroAzar		
		move $t3, $v0		# t3 = primer random number
		
		li $a0, 0
		move $a1, $s7		# preparar argumento para la funcion "azar", a1 = altura-1
		jal numeroAzar
		move $t4, $v0		# t4 = primer random number	
					
					# Argumentos para chequear colision
		move $a0, $t3		# a0 = numero random X
		move $a1, $t4		# a1 = numero random Y

		jal chequearColisionObstaculos	# 				# Si la comida colisiona con un obstaculo
		beqz $v0, aparecerComidaEnLugarNuevoNoColisionaConObstaculo	# repetir busqueda de numero random
		
		# Insertar codigo aca en caso de que se haya detectado una colision 
		# al generar una comida, con un obstaculo
		# (no hacer nada, ya que el codigo para generar comida
		# se repetira hasta que no colisione nada)
		
		j aparecerComidaEnLugarNuevoGenerarRandom
		aparecerComidaEnLugarNuevoNoColisionaConObstaculo:
		# comidaX = random
		la $t1, comidaX
		sw $t3, 0($t1)
				
		# comidaY = random
		la $t1, comidaY
		sw $t4, 0($t1)		

		
		move $ra, $s2			
		jr $ra
			
	# Argumentos: -
	# Retorno: -
	# Descripcion: Genera los obstaculos para el nivel. Escribe en memoria las posiciones de cada obstaculo. (no los pinta)
	generarObstaculos:		
		move $s1, $ra		
		la $t0, obstaculos
		li $t1, 0			# t1 = 0, i=0
		la $t2, cabezaSerpienteX
		lw $t2, 0($t2)
		la $t3, cabezaSerpienteY
		lw $t3, 0($t3)

		generarObstaculosFor:
			beq $t1, 100, generarObstaculosFinFor
			
			# Generar X,Y al azar.
			
			li $a0, 0		# rango para numero al azar
			la $a1, mapaAncho
			lw $a1, 0($a1)
			addi $a1, $a1, -1	
			jal numeroAzar
			move $t4, $v0
			
			li $a0, 0		# rango para numero al azar
			la $a1, mapaAltura
			lw $a1, 0($a1)
			addi $a1, $a1, -1		
			jal numeroAzar		
			move $t5, $v0		
			
			seq $t7, $t4, $t2	# t7 = (cabeza.x == obstaculo.x)
			seq $t8, $t5, $t3	# t8 = (cabeza.y == obstaculo.y)
			and $t7, $t7, $t8	# t7 = t7 AND t8
			beq $t7, 1, generarObstaculosFor
			
			sw $t4, 0($t0)
			sw $t5, 4($t0)
			
			
			addi $t0, $t0, 8	# siguiente dato del arreglo			
			addi $t1, $t1, 1	# i++
			j generarObstaculosFor
		generarObstaculosFinFor:
		move $ra, $s1
		jr $ra
		
	# Argumentos: a2
	# Retorno: -
	# Descripcion: Pinta los obstaculos en el mapa, del color a2
	pintarObstaculos:		
		move $s1, $ra		
		la $t3, obstaculos
		li $t4, 0		# t1 = 0, i=0
		pintarObstaculosFor:
			beq $t4, 100, pintarObstaculosFinFor
			
			lw $a0, 0($t3)	# X del obstaculo
			lw $a1, 4($t3)	# Y del obstaculo
			jal pintarCuadro
			
			addi $t3, $t3, 8	# siguiente dato del arreglo			
			addi $t4, $t4, 1	# i++
			j pintarObstaculosFor
		pintarObstaculosFinFor:
		move $ra, $s1
		jr $ra
			
	# Argumentos: -
	# Retorno: -
	# Descripcion: Crea un nuevo elemento para la cola. Este elemento tiene inicialmente la misma posicion
	# que el elemento anterior a el (otro elemento de la cola, o bien la cabeza).
	crecerCola:		
		la $t0, largoCola		# largoCola ++
		lw $t1, 0($t0)
		addi $t1, $t1, 1
		sw $t1, 0($t0)
				
		la $t1, largoCola		# t1 = direccion largoCola
		lw $t1, 0($t1)			# t1 = largo cola
		move $t2, $t1			# t2 = largo cola (copia)
		beq $t1, $zero, crecerCola_fin	# Si no hay cola, ir a FIN
		addi $t1, $t1, -1		# t1 --	
		sll $t1, $t1, 3			# t1 = largoCola*8
		
		li $t0, 0x10040000		# direccion inicial del heap
		add $t0, $t0, $t1		# t0 = direccion inicial heap + t1
		
		# Ahora se tiene la direccion ($t0) de donde va la nueva estructura
		# de dato X,Y para el nuevo elemento de la cola
		sgt $t1, $t2, 1			# if( largoCola > 1) { $t1 = true }
		beq $t1, $zero, copiarPosCabeza	# Si t1=false, solo hay un elemento en la cola. Copiar la posicion de la cabeza
		
		copiarPosElementoAnterior:
			move $t1, $t0		# t1 = posicion en el heap que contiene el elemento recien agregado
			addi $t1, $t1, -8	# t1 = posicion en el heap del elemento anterior (coordenada X)
			lw $t2, 0($t1)		# t2 = coordenada X del elemento anterior
			sw $t2, 0($t0)		# guardar coordenada X del elem. anterior, en la X del elemento nuevo
			addi $t0, $t0, 4	# +4 para ahora trabajar con la posicion Y del elemento nuevo
			addi $t1, $t1, 4	# +4 para ahora trabajar con la posicion Y del elemento anterior
			
			lw $t1, 0($t1)		# t1 = coordenada Y del elemento anterior
			sw $t1, 0($t0)		# guardar coordenada Y del elem. anterior, en la Y del elemento nuevo			
			
		j crecerCola_fin		# Terminar ejecucion
		copiarPosCabeza:
			la $t1, cabezaSerpienteX	# t1 = direccion cabeza.x
			lw $t1, 0($t1)			# t1 = cabeza.x
			sw $t1, 0($t0)			# guardar cabeza.x en la posicion X del nuevo elemento
			addi $t0, $t0, 4		# +4 para ahora trabajar con la posicion Y
			
			la $t1, cabezaSerpienteY	# t1 = direccion cabeza.y
			lw $t1, 0($t1)			# t1 = cabeza.y
			sw $t1, 0($t0)			# guardar cabeza.y en la posicion Y del nuevo elemento
			
		crecerCola_fin:		
		jr $ra
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Verifica si se come una comida y aumenta el puntaje y crea otra nueva comida.
	chequearComeComida:	
		move $s3, $ra
		
		# Primero se chequea si las X==X de la cabeza serpiente y comida
		
		la $t0, comidaX			# t0 = comida.x
		lw $t0, 0($t0)		
		la $t1, cabezaSerpienteX	# t1 = cabeza.x
		lw $t1, 0($t1)
		beq $t0, $t1, chequearComeComida2		
		jr $ra
		
		# En caso de que se continue ejecutando la funcion
		# se chequea si las coordenadas Y son iguales
		
		chequearComeComida2:
		la $t2, comidaY			# t2 = comida.y
		lw $t2, 0($t2)		
		la $t3, cabezaSerpienteY	# t3 = cabeza.y
		lw $t3, 0($t3)
		beq $t2, $t3, chequearComeComidaVERDADERO
		jr $ra
		
		chequearComeComidaVERDADERO:

		jal aparecerComidaEnLugarNuevo			
		
		jal crecerCola			# crecer cola (agregar nuevo elemento)
		
		move $ra, $s3
		jr $ra		
	
	# Argumentos: -
	# Retorno: v0
	# Descripcion: Retorna verdadero si la serpiente ha tocado con su cabeza, alguna parte de su cola.
	chequearColisionConsigoMisma:
		li $v0, 0		# falso por default
		la $t0, largoCola
		lw $t0, 0($t0)		# t0 = largoCola
		li $t1, 3		# t1 = 3 ... i=3 
		li $t2, 0x10040018	# direccion heap
		
		la $t6, cabezaSerpienteX
		lw $t6, 0($t6)
		la $t7, cabezaSerpienteY
		lw $t7, 0($t7)
		
		forColisionConsigoMisma:
			sge $t3, $t1, $t0			# if (i >= largoCola) {
			bgtz $t3, finForColisionConsigoMisma	# 	return;
								# }						
				lw $t4, 0($t2)			# X del elemento i de la cola
				bne $t4, $t6, forColisionConsigoMismaIncremento
				
				lw $t4, 4($t2)			# Y del elemento i de la cola
				beq $t4, $t7, huboColisionConsigoMisma
				
				forColisionConsigoMismaIncremento:					
				addi $t2, $t2, 8		
				addi $t1, $t1, 1	# i++
			j forColisionConsigoMisma
			
			huboColisionConsigoMisma:
			li $v0, 1
		finForColisionConsigoMisma:
		jr $ra
	
		
	# Argumentos: a0, a1
	# Retorno: v0
	# Descripcion: Retorna verdadero si un objeto de coordenadas a0, a1 ha tocado un obstaculo.
	chequearColisionObstaculos:
	
		la $t0, obstaculos
		li $t1, 0		# t1 = 0, i=0
		li $v0, 0		# no hay colision, retorno default

		chequearColisionObstaculosFor:
			beq $t1, 100, chequearColisionObstaculosFinFor
						
			lw $t2, 0($t0)	# X del obstaculo
			bne $t2, $a0, chequearColisionObstaculosForIncrementar
						
			lw $t2, 4($t0)	# Y del obstaculo
			beq $t2, $a1, huboColisionObstaculo
			
			chequearColisionObstaculosForIncrementar:
			addi $t0, $t0, 8	# siguiente dato del arreglo			
			addi $t1, $t1, 1	# i++
			j chequearColisionObstaculosFor
			
			huboColisionObstaculo:
			li $v0, 1
		chequearColisionObstaculosFinFor:

	jr $ra
	
	# Argumentos: $a0, $a1
	# Retorno: $v0, $v1
	# Descripcion: Esta funcion retorna la posicion X,Y de la cabeza de la serpiente, la cual corresponde a
	# la posicion en la que aparece al atravesar la muralla limite y volver por el lado contrario. Esta funcion retorna un valor igual al de
	# los argumentos en caso de que no se haya atravesado la muralla (por ejemplo, si el limite es x=50, y la cabeza ha pasado a x=51, esta
	# funcion retorna 1.)
	cabezaDentroDeLimites:
		
		move $v0, $a0
		move $v1, $a1
		
		la $t0, mapaAncho			# t0 = mapa ancho
		lw $t0, 0($t0)
		beq $t0, $a0, excesoX			# mapa ancho == X (entrada)
		beq $a0, -1, deficitX			# -1 == X (entrada)
		
		j calcularLimitesY			# bypass ambos casos
		excesoX:
			li $v0, 0			# X = 0		
			j calcularLimitesY		# saltarse la linea siguiente
		deficitX:
			addi $t0, $t0, -1
			move $v0, $t0			# situar la X al margen del mapa
			
		calcularLimitesY:
		
		la $t0, mapaAltura			# t0 = mapa altura
		lw $t0, 0($t0)
		beq $t0, $a1, excesoY			# mapa altura == Y (entrada)
		beq $a1, -1, deficitY			# -1 == Y (entrada)
		
		j calcularLimitesFin			# bypass ambos casos
		excesoY:
			li $v1, 0			# Y = 0			
			j calcularLimitesFin
		deficitY:
			addi $t0, $t0, -1
			move $v1, $t0
		calcularLimitesFin:
		
		jr $ra
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Mueve la cabeza de la serpiente, utilizando el valor de la "direccion" para definir hacia donde debe moverse.
	moverCabezaSerpiente:
		move $s0, $ra
		la $t0, direccion
		lw $t0, 0($t0)
		
		li $t1, 1
		beq $t0, $t1, moverCabezaSerpiente_left
		li $t1, 2
		beq $t0, $t1, moverCabezaSerpiente_up
		li $t1, 3
		beq $t0, $t1, moverCabezaSerpiente_right
		li $t1, 4
		beq $t0, $t1, moverCabezaSerpiente_down
		
		moverCabezaSerpiente_left:
			la $t0, cabezaSerpienteX
			lw $t1, 0($t0)
			addi $t1, $t1, -1
			sw $t1, 0($t0)			
			j moverCabezaSerpiente_fin
		moverCabezaSerpiente_up:
			la $t0, cabezaSerpienteY
			lw $t1, 0($t0)
			addi $t1, $t1, -1
			sw $t1, 0($t0)	
			j moverCabezaSerpiente_fin
		moverCabezaSerpiente_right:
			la $t0, cabezaSerpienteX
			lw $t1, 0($t0)
			addi $t1, $t1, 1
			sw $t1, 0($t0)	
			j moverCabezaSerpiente_fin
		moverCabezaSerpiente_down:
			la $t0, cabezaSerpienteY
			lw $t1, 0($t0)
			addi $t1, $t1, 1
			sw $t1, 0($t0)	
			j moverCabezaSerpiente_fin
			
		moverCabezaSerpiente_fin:
		
		la $t4, cabezaSerpienteX		# Procesar los cambios de coordenadas de la cabeza
		lw $a0, 0($t4)				# para asi hacer que al atravesar una pared
		la $t5, cabezaSerpienteY		# salga por el lado contrario
		lw $a1, 0($t5)
		
		jal cabezaDentroDeLimites
		sw $v0, 0($t4)
		sw $v1, 0($t5)
		
		move $ra, $s0				# recuperar direccion para volver el caller
		jr $ra
		
	# Argumentos: -
	# Retorno: -
	# Descripcion: Mueve la cola de la serpiente. El algoritmo usado es, empezar desde el ultimo elemento de la cola (el mas lejano a
	# la cabeza, y asignarle a este, la posicion del anterior. Iterando se llega hasta el primer elemento de la cola, el cual copia
	# la posicion de la cabeza.
	moverColaSerpiente:
		la $t0, largoCola		# t0 = largoCola
		lw $t0, 0($t0)
		
		
		# Si la cantidad de elementos en la cola es 0 o 1
		li $t2, 1
		beq $t0, $t2, moverColaSerpiente_finFor		# si es 1
		beqz $t0, moverColaSerpiente_finFor		# si es 0
		
		addi $t0, $t0, -1
		li $t1, 0x10040000		# dir. inicial heap
		move $t2, $t0			# t2 = largoCola
		#addi $t2, $t2, -1		# t2 --
		sll $t2, $t2, 3			# t2 *= 8
		add $t2, $t1, $t2		# direccion del ultimo elemento de la cola
		li $t3, 0			# t3=0 , i=0
		
		moverColaSerpiente_for:
			beq $t2, 0x10040000, moverColaSerpiente_finFor # Salirse del for si i==largoCola	
			
			lw $t1, -8($t2)				# t1 = valor de X del elemento anterior
			sw $t1, 0($t2)				# guardar t1 en el X del elemento actual
			
			lw $t1, -4($t2)				# t1 = valor de Y del elemento anterior
			sw $t1, 4($t2)				# guardar t1 en el Y del elemento actual
			
			addi $t2, $t2, -8			
			#addi $t3, $t3, 1
			
			j moverColaSerpiente_for
		moverColaSerpiente_finFor:	
		
		la $t0, cabezaSerpienteX
		lw $t0, 0($t0)			# t0 cabeza.x (serpiente)
		sw $t0, 0x10040000
		la $t0, cabezaSerpienteY
		lw $t0, 0($t0)			# t0 cabeza.y (serpiente)
		sw $t0, 0x10040004		
	
		jr $ra
		
	# Argumentos: $a0
	# Retorno: -
	# Descripcion: Pinta el mapa entero del color $a0
	pintarFondo:
		# Obtener la direccion del display
		la $t0, display
		
		# Borrar todo el mapa, pintandolo de negro
		li $t1, 0		# i = 0
		add $t2, $t0, $zero	# t2 = direccion display
		li $t3, 4096		# dimension total del display
		add $t4, $zero, $a0	# color del fondo		
				
		pintarFondo_borrarMapa_for:
			beq $t1, $t3, pintarFondo_borrarMapa_finFor	# si i=t3, ir a fin de for			 			
			sw $t4, 0($t2)					# pintar t2 con el color t5
			addi $t2, $t2, 4				# dimension += 4			
			addi $t1, $t1, 1				# i++
			j pintarFondo_borrarMapa_for
		pintarFondo_borrarMapa_finFor:
	jr $ra
		
	# Argumentos: -
	# Retorno: -
	# Descripcion: Pinta la serpiente, comidas, y puntaje, con el color de fondo, borrando asi solo lo que sea necesario.
	
	despintarRegionesRedibujo:
		move $s0, $ra
		
		
		# desPintar comida
		
		li $a2, 0x000000	# color para la comida
		la $t3, comidaX
		lw $a0, 0($t3)		# a0 = comida.x
		
		la $t4, comidaY
		lw $a1, 0($t4)		# a1 = comida.y		
		jal pintarCuadro
		
		
		# desPintar cola serpiente
		#li $a2, 0x000000
		la $t3, largoCola
		lw $t3, 0($t3)			# t3 = largo cola
		beq $t3, 0, despintarSoloCabeza	# no hacer nada si largo cola = 0
		addi $t3, $t3, -1		# largo cola -1
		sll $t3, $t3, 3			# t3 * 8
		addi $a0, $t3, 0x10040000
		lw $a1, 4($a0)
		lw $a0, 0($a0)		
		li $a2, 0x000000
		jal pintarCuadro
		j finDespintar			# Despintando el ultimo cuadro de la cola
						# no es necesario despintar la cabeza
		
		despintarSoloCabeza:
		# desPintar cabeza
		
		li $a2, 0x000000	# color para la cabeza
		la $t3, cabezaSerpienteX
		lw $a0, 0($t3)		# a0 = cabeza.x
		
		la $t4, cabezaSerpienteY
		lw $a1, 0($t4)		# a1 = cabeza.y		
		jal pintarCuadro
		
		finDespintar:
		move $ra, $s0
	jr $ra
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Pinta en el mapa, la comida y cabeza de la serpiente.
	
	pintarTodo:	
		move $s1, $ra
		li $a0, 0x00
		
		# Obtener la direccion del display
		la $t0, display		# t0 = direccion del display
				
		
		# Pintar cabeza
		
		li $a2, 0xff0000	# color para la cabeza
		la $t3, cabezaSerpienteX
		lw $a0, 0($t3)		# a0 = cabeza.x
		
		la $t4, cabezaSerpienteY
		lw $a1, 0($t4)		# a1 = cabeza.y		
		jal pintarCuadro

		# Pintar comida
		
		li $a2, 0xffff00	# color para la comida
		la $t3, comidaX
		lw $a0, 0($t3)		# a0 = comida.x
		
		la $t4, comidaY
		lw $a1, 0($t4)		# a1 = comida.y		
		jal pintarCuadro
				
		# Pintar cola serpiente
		li $a2, 0xff0000
		jal pintarColaSerpiente		
				
		move $ra, $s1
	jr $ra
	
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Pinta los digitos del puntaje, en pantalla.
	pintarDigitosPuntaje:
		move $s2, $ra
		
		
		jal pintarContenedorNegroDisplayPuntaje	
		
		# Conseguir las unidades y decenas

		la $t0, largoCola
		lw $t0, 0($t0)
		li $t1, 0		# t1 = 0
		li $t2, 10		# t2 = 10
		
		obtenerDigitoUnidadWhile:
			div $t0, $t2
			mfhi $t3
			beqz $t3, obtenerDigitoUnidadWhileFin
			addi $t0, $t0, -1	# t0--
			addi $t1, $t1, 1	# contador de unidades
		
		j obtenerDigitoUnidadWhile
		obtenerDigitoUnidadWhileFin:
		mflo $a2		# contiene la decena
		move $t9, $t1		# t9 = contiene las unidades
		
		# pasar el numero como $a2 a pintarDigito	
		
		li $a0, 3
		li $a1, 56
		jal pintarDigito
		
		move $a2, $t9
		li $a0, 7
		li $a1, 56
		jal pintarDigito		
		
		move $ra, $s2	
	jr $ra	
	
	
	# Argumentos: a0, a1, a2
	# Retorno: -
	# Descripcion: Pinta un digito (a2), usando como desplazamiento el vector (a0,a1)
	pintarDigito:		
		move $s3, $ra		
		
		beq $a2, 0, pintar0
		beq $a2, 1, pintar1
		beq $a2, 2, pintar2
		beq $a2, 3, pintar3
		beq $a2, 4, pintar4
		beq $a2, 5, pintar5
		beq $a2, 6, pintar6
		beq $a2, 7, pintar7
		beq $a2, 8, pintar8
		beq $a2, 9, pintar9
		j finPintarDigito
		
		# Los argumentos a0 y a1 se pasan nuevamente
		# a las siguientes funciones
		
		pintar0:
			li $a2, 1
			jal pintarSegmento
			li $a2, 2
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
			li $a2, 4
			jal pintarSegmento
			li $a2, 5
			jal pintarSegmento
			li $a2, 6
			jal pintarSegmento
		j finPintarDigito
		pintar1:
			li $a2, 2
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
		
		j finPintarDigito
		pintar2:
			li $a2, 1
			jal pintarSegmento
			li $a2, 2
			jal pintarSegmento
			li $a2, 7
			jal pintarSegmento
			li $a2, 5
			jal pintarSegmento
			li $a2, 4
			jal pintarSegmento
		
		j finPintarDigito
		pintar3:
			li $a2, 1
			jal pintarSegmento
			li $a2, 2
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
			li $a2, 4
			jal pintarSegmento
			li $a2, 7
			jal pintarSegmento
		
		j finPintarDigito
		pintar4:
			li $a2, 6
			jal pintarSegmento
			li $a2, 7
			jal pintarSegmento
			li $a2, 2
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
		
		j finPintarDigito
		pintar5:
			li $a2, 1
			jal pintarSegmento
			li $a2, 6
			jal pintarSegmento
			li $a2, 7
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
			li $a2, 4
			jal pintarSegmento
		
		j finPintarDigito
		pintar6:
			li $a2, 1
			jal pintarSegmento
			li $a2, 6
			jal pintarSegmento
			li $a2, 5
			jal pintarSegmento
			li $a2, 4
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
			li $a2, 7
			jal pintarSegmento
		
		j finPintarDigito
		pintar7:
			li $a2, 1
			jal pintarSegmento
			li $a2, 2
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
		
		j finPintarDigito
		pintar8:
			li $a2, 1
			jal pintarSegmento
			li $a2, 2
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
			li $a2, 4
			jal pintarSegmento
			li $a2, 5
			jal pintarSegmento
			li $a2, 6
			jal pintarSegmento
			li $a2, 7
			jal pintarSegmento
		
		j finPintarDigito
		pintar9:
			li $a2, 1
			jal pintarSegmento
			li $a2, 2
			jal pintarSegmento
			li $a2, 3
			jal pintarSegmento
			li $a2, 6
			jal pintarSegmento
			li $a2, 7
			jal pintarSegmento
		
		finPintarDigito:		
	move $ra, $s3
	jr $ra
	
	
	# Argumentos: a0, a1, a2
	# Retorno: -
	# Descripcion: Pinta un segmento (similar a los de los display de 7 trazos). Pinta el segmento a2, con un desplace de a0,a1 (X,Y)
	pintarSegmento:
		move $s4, $ra	
		
		move $t4, $a0		# respaldar a0 = X
		move $t5, $a1		# respaldar a1 = Y
		move $t3, $a2		# respaldar a2 = segmento
		li $a2, 0x000000ff	# Color para pintar los numeros
		beq $t3, 1, seg1
		beq $t3, 2, seg2
		beq $t3, 3, seg3
		beq $t3, 4, seg4
		beq $t3, 5, seg5
		beq $t3, 6, seg6
		beq $t3, 7, seg7
		j finPintarSegmento

		seg1:
			add $a0, $t4, 0		# conseguir posicion X
			add $a1, $t5, 0		# conseguir posicion Y
			jal pintarCuadro
			
			add $a0, $t4, 1		# conseguir posicion X
			jal pintarCuadro
			
			add $a0, $t4, 2		# conseguir posicion X
			jal pintarCuadro
		
		
		j finPintarSegmento
		seg2:
			add $a0, $t4, 2		# conseguir posicion X
			add $a1, $t5, 0		# conseguir posicion Y
			jal pintarCuadro
			
			add $a1, $t5, 1		# conseguir posicion Y
			jal pintarCuadro
			
			add $a1, $t5, 2		# conseguir posicion Y
			jal pintarCuadro
		
		j finPintarSegmento
		seg3:
			add $a0, $t4, 2		# conseguir posicion X
			add $a1, $t5, 2		# conseguir posicion Y
			jal pintarCuadro
			
			add $a1, $t5, 3		# conseguir posicion Y
			jal pintarCuadro
			
			add $a1, $t5, 4		# conseguir posicion Y
			jal pintarCuadro
		
		j finPintarSegmento
		seg4:
			add $a0, $t4, 0		# conseguir posicion X
			add $a1, $t5, 4		# conseguir posicion Y
			jal pintarCuadro
			
			add $a0, $t4, 1		# conseguir posicion X
			jal pintarCuadro
			
			add $a0, $t4, 2		# conseguir posicion X
			jal pintarCuadro
		
		j finPintarSegmento
		seg5:
			add $a0, $t4, 0		# conseguir posicion X
			add $a1, $t5, 2		# conseguir posicion Y
			jal pintarCuadro
			
			add $a1, $t5, 3		# conseguir posicion Y
			jal pintarCuadro
			
			add $a1, $t5, 4		# conseguir posicion Y
			jal pintarCuadro
		
		j finPintarSegmento
		seg6:
			add $a0, $t4, 0		# conseguir posicion X
			add $a1, $t5, 0		# conseguir posicion Y
			jal pintarCuadro
			
			add $a1, $t5, 1		# conseguir posicion Y
			jal pintarCuadro
			
			add $a1, $t5, 2		# conseguir posicion Y
			jal pintarCuadro
		
		j finPintarSegmento
		seg7:
			add $a0, $t4, 0		# conseguir posicion X
			add $a1, $t5, 2		# conseguir posicion Y
			jal pintarCuadro
			
			add $a0, $t4, 1		# conseguir posicion X
			jal pintarCuadro
			
			add $a0, $t4, 2		# conseguir posicion X
			jal pintarCuadro
		
		j finPintarSegmento
		
		finPintarSegmento:
		move $a0, $t4
		move $a1, $t5
		
	move $ra, $s4	
	jr $ra	
	
	# Argumentos: a2
	# Retorno: -
	# Descripcion: Pintar cola de la serpiente, color = a2
	pintarColaSerpiente:	
		move $s2, $ra
		la $s4, largoCola
		lw $s4, 0($s4)					# s4 = largo cola
		li $s3, 0					# s3 = 0 .. i=0
		li $s5, 0x10040000				# s5 = dir. heap
				
		pintarColaSerpiente_for:
			beq $s3, $s4, pintarColaSerpiente_finFor # Salirse del for si i==largoCola			
			
			lw $a0, 0($s5)				# obtener X
			lw $a1, 4($s5)				# obtener Y			
			jal pintarCuadro			# pintar el cuadro			
			
			addi $s5, $s5, 8			# pasar al siguiente dato
		
			addi $s3, $s3, 1			# i++	
			
			j pintarColaSerpiente_for
		pintarColaSerpiente_finFor:
		move $ra, $s2
	jr $ra	

	# Argumentos: $a0, $a1, $a2
	# Retorno: -
	# Descripcion: De los argumentos, obtiene un par ordenado X,Y, un color, y dibuja este cuadro en la posicion que debiera
	# estar para que aparezca bien en el display.
	pintarCuadro:	
		la $t0, mapaAncho	# t0 = direccion de mapaAncho
		lw $t0, 0($t0)		# t0 = mapaAncho
		add $t2, $a0, $zero	# t2 = X (a0)
		add $t1, $a1, $zero	# t1 = Y (a1)
		mult $t1, $t0		# Y * mapaAncho
		mflo $t1		# t1 = resultado de la multiplicacion anterior
		add $t2, $t2, $t1	# t2 = X + (Y*mapaAncho)
		sll $t2, $t2, 2		# *=4		
		la $t0, display		# t0 = display
		add $t0, $t0, $t2	# t0 = display + X + (Y*mapaAncho)	
		
		sw $a2, 0($t0)		# pintar el color a2 en la direccion t0		
	jr $ra
	
	# Argumentos: -
	# Retorno: -
	# Descripcion: Pinta un rectangulo el cual contiene el display del puntaje. Esto sirve para borrar el puntaje anterior.
	pintarContenedorNegroDisplayPuntaje:
		move $s3, $ra
		li $t5, 3
		li $t6, 56
		li $a2, 0x222222
		
		for_ContainerNegro2:
		beq $t6, 61, finFor_ContainerNegro2
		
		for_ContainerNegro:
		beq $t5, 10, finFor_ContainerNegro
			move $a0, $t5
			move $a1, $t6
			jal pintarCuadro
		
		addi $t5, $t5, 1
		j for_ContainerNegro
		finFor_ContainerNegro:
		
		li $t5, 3
		
		
		addi $t6, $t6, 1
		j for_ContainerNegro2
		finFor_ContainerNegro2:
		
	move $ra, $s3
	jr $ra

